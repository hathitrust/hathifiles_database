# HathifilesDatabase

Code to take data from the [hathifiles](https://github.com/hathitrust/hathifiles)
and keep an up-to-date set of tables in mysql for querying by HT staff.

## Developer Setup
```
git clone <URL/protocol of choice>
cd hathifiles_database
docker compose build
docker compose run --rm test bin/setup
docker compose run --rm test
docker compose run --rm test bundle exec standardrb
```

## Structure

There are six tables: one with all the data in the hathifiles
(some of it normalized) in the same order we have there, and 
four where we break out and index normalized versions of the 
standard identifiers.

`hf_log` records each hathifile as it is successfully loaded (along with a timestamp)
so that updates can occur in batches, as needed, for date independence.

* hf
* hf_isbn
* hf_issn
* hf_lccn
* hf_oclc
* hf_log

ISBNs, ISSNs, and OCLC numbers are indexed after normalization (just
 runs of digits and potentially an upper-case 'x'). In addition, ISBNs
  are indexed in both their 10- and 13-character forms.
  
LCCNs are more of a mess. They're stored twice, too -- one normalized
 and what with whatever string was in the MARC record.

## Binaries
```
bin
├── console
└── setup
```
These are intended to be run under Docker for development purposes.

- `console` invokes `irb` with `hathifiles_database` pre-`require`d
- `setup` is just a shell wrapper around `bundle install` (see Developer Setup)

```
exe
└── hathifiles_database_full_update
```
This is exported by the `gemspec` as the gem's executable.

- `hathifiles_database_full_update` the preferred date-independent method for loading `full` and `upd` hathifiles


## Environment Variables
- Default Database Credentials -- override by passing keyword arguments to the `DB::Connection` initializer.
  - `MARIADB_HATHIFILES_RW_USERNAME`
  - `MARIADB_HATHIFILES_RW_PASSWORD`
  - `MARIADB_HATHIFILES_RW_HOST`
  - `MARIADB_HATHIFILES_RW_DATABASE`
  - `MARIADB_HATHIFILES_RW_EXTRA_FLAGS` - any extra flags required for the `mariadb` command-line client
- Filesystem
  - `HATHIFILES_DIR` path to hathifiles archive
- Other
  - `PUSHGATEWAY` Prometheus push gateway URL

## Pitfalls

The `hf` database does not record exactly the same data as the hathifiles.
In particular, standard numbers like ISBN and ISSN are normalized.
Furthermore `access` is a Boolean in the database, but in the hathifiles it appears as
`allow` or `deny`. Because of the `library_stdnums` normalization, it is not possible
to do a round-trip conversion from database to hathifile, only the reverse.
As a result of this, the monthly update (which computes a diff before making changes to
the database) dumps the `hathi_full_*` file into an intermediate "DB-ized" dialect for
comparison.

The `push_metrics` gem, which is required for running `exe/hathifiles_database_full_update`,
is not part of the gemspec because it is currently unpublished. Code which uses `hathifiles_database`
as a gem should also declare a `push_metrics` dependency or use its own implementation
of `hathifiles_database_full_update`.

## Some query examples

Get info for records with the given issn

```sql
select hf.htid, title from hf 
join hf_issn on hf.htid=hf_issn.htid 
where hf_issn.value="0134045X";
```

Find govdocs whose rights were added/changed in the last two years.
Note, sadly, that you can't say "3 days", but must use "3 day"
or "2 year" or whatnot.

```sql
select count(*) from hf where us_gov_doc_flag = 1 AND
rights_timestamp > date_sub(now(), interval 2 year);
```

What's the rights breakdown for stuff sent by Tufts?

```sql
select rights_code, count(*) from hf where 
content_provider_code='tufts' 
group by rights_code;
```

Who's giving us stuff from the 18th century?
```sql
select content_provider_code, count(*) from hf 
where rights_date_used between 1700 and 1799 
group by content_provider_code 
order by count(*) desc;
```

Reconstitute a full hathifile line (given some query criterion) with the fields as in the [Hathifiles Description](https://www.hathitrust.org/member-libraries/resources-for-librarians/data-resources/hathifiles/hathifiles-description/)

```sql
select 
  hf.htid, access, rights_code as rights, bib_num as ht_bib_key, description, source, source_bib_num,
  group_concat(DISTINCT oclc.value SEPARATOR ',') oclc_num,
  group_concat(DISTINCT isbn.value SEPARATOR ',') isbn,
  group_concat(DISTINCT issn.value SEPARATOR ',') issn,
  group_concat(DISTINCT lccn.value SEPARATOR ',') lccn,
  title, imprint, rights_reason as rights_reason_code, rights_timestamp, us_gov_doc_flag, rights_date_used,
  pub_place, lang_code as lang, bib_fmt, collection_code, content_provider_code, responsible_entity_code,
  digitization_agent_code, access_profile_code, author
from hf
left outer join hf_oclc oclc on oclc.htid = hf.htid
left outer join hf_isbn isbn on isbn.htid = hf.htid
left outer join hf_issn issn on issn.htid = hf.htid
left outer join hf_lccn lccn on lccn.htid = hf.htid
where ...
group by hf.htid
```

## A quick word about other HT tables

Because of... well, _because_, not all tables use the same conventions
for identifying a volume.

If you want to, you can use the hf.htid column to link into other tables
as follows.

* **rights_current**: `hf.htid = concat(rights_current.namespace
,'.', rights_current.id)` # will be sloooooooow
* **holdings_htitem_htmember**: `hf.htid = holdings_htitem_htmember
.volume_id`
 
