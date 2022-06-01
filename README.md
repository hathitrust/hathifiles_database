# HathifilesDatabase

Code to take data from the [hathifiles]() and keep an up-to-date
set of tables in mysql for querying by HT staff.

## Structure

There are five tables: one with all the data in the hathifiles
(some of it normalized) in the same order we have there, and 
four where we break out and index normalized versions of the 
standard identifiers. 

* hf
* hf_isbn
* hf_issn
* hf_lccn
* hf_oclc

ISBNs, ISSNs, and OCLC numbers are indexed after normalization (just
 runs of digits and potentially an upper-case 'x'). In addition, ISBNs
  are indexed in both their 10- and 13-character forms.
  
LCCNs are more of a mess. They're stored twice, too -- one normalized
 and what with whatever string was in the MARC record.
 
## Some query examples

```sql
-- Get info for records with the given issn

select hf.htid, title from hf 
join hf_issn on hf.htid=hf_issn.htid 
where hf_issn.value="0134045X";

-- Find govdocs whose rights were added/changed in the last two years.
-- Note, sadly, that you can't say "3 days", but must use "3 day"
-- or "2 year" or whatnot.

select count(*) from hf where us_gov_doc_flag = 1 AND
rights_timestamp > date_sub(now(), interval 2 year);

-- What's the rights breakdown for stuff sent by Tufts?
select rights_code, count(*) from hf where 
content_provider_code='tufts' 
group by rights_code;

-- Who's giving us stuff from the 18th century?
select content_provider_code, count(*) from hf 
where rights_date_used between 1700 and 1799 
group by content_provider_code 
order by count(*) desc;

-- Reconstitute all hathifiles fields
select hf.*,
       group_concat(DISTINCT oclc.value SEPARATOR ',') oclc,
       group_concat(DISTINCT isbn.value SEPARATOR ',') isbn,
       group_concat(DISTINCT issn.value SEPARATOR ',') issn,
       group_concat(DISTINCT lccn.value SEPARATOR ',') lccn
from hf
left outer join hf_oclc oclc on oclc.htid = hf.htid
left outer join hf_isbn isbn on isbn.htid = hf.htid
left outer join hf_issn issn on issn.htid = hf.htid
left outer join hf_lccn lccn on lccn.htid = hf.htid
where ...
group by hf.htid;

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
 
