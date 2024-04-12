# frozen_string_literal: true

require "tempfile"
require_relative "../lib/hathifiles_database/delta"

RSpec.describe HathifilesDatabase::Delta do
  describe "updates" do
    context "with a real updates file" do
      it "reports correct membership" do
        Tempfile.open("updates") do |file|
          file.write "abc\ndef\n"
          file.close
          delta = described_class.new(updates_file: file.path)
          expect(delta.updates.include?("abc")).to eq true
          expect(delta.updates.include?("def")).to eq true
          expect(delta.updates.include?("xyz")).to eq false
          expect(delta.updated?("abc")).to eq true
          expect(delta.updated?("def")).to eq true
          expect(delta.updated?("xyz")).to eq false
        end
      end
    end

    context "with a fake updates file" do
      it "reports correct membership" do
        delta = described_class.new
        expect(delta.updates.include?("abc")).to eq true
        expect(delta.updates.include?("def")).to eq true
        expect(delta.updates.include?("xyz")).to eq true
        expect(delta.updated?("abc")).to eq true
        expect(delta.updated?("def")).to eq true
        expect(delta.updated?("xyz")).to eq true
      end
    end
  end

  describe "deletes" do
    context "with a real deletes file" do
      it "reports correct membership" do
        Tempfile.open("deletes") do |file|
          file.write "abc\ndef\n"
          file.close
          delta = described_class.new(deletes_file: file.path)
          expect(delta.deletes.include?("abc")).to eq true
          expect(delta.deletes.include?("def")).to eq true
          expect(delta.deletes.include?("xyz")).to eq false
          expect(delta.deleted?("abc")).to eq true
          expect(delta.deleted?("def")).to eq true
          expect(delta.deleted?("xyz")).to eq false
        end
      end
    end

    context "with a fake deletes file" do
      it "reports correct membership" do
        delta = described_class.new
        expect(delta.deletes.include?("abc")).to eq false
        expect(delta.deletes.include?("xyz")).to eq false
        expect(delta.deleted?("abc")).to eq false
        expect(delta.deleted?("xyz")).to eq false
      end
    end
  end
end
