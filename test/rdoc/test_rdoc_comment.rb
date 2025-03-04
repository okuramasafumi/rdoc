# coding: us-ascii
# frozen_string_literal: true

require_relative 'helper'

class RDocCommentTest < RDoc::TestCase

  def setup
    super

    @top_level = @store.add_file 'file.rb'
    @comment = RDoc::Comment.new
    @comment.location = @top_level
    @comment.text = 'this is a comment'
  end

  def test_empty
    @comment.text = ''
    assert_empty @comment
    empty_doc = @comment.parse
    assert_empty @comment
    @comment.text = 'a'
    refute_empty @comment
    present_doc = @comment.parse
    refute_empty @comment
    assert_empty RDoc::Comment.from_document(empty_doc)
    refute_empty RDoc::Comment.from_document(present_doc)
  end

  def test_equals2
    assert_equal @comment, @comment.dup

    c2 = @comment.dup
    c2.text = nil

    refute_equal @comment, c2

    c3 = @comment.dup
    c3.location = nil

    refute_equal @comment, c3
  end

  def test_extract_call_seq
    comment = RDoc::Comment.new <<-COMMENT, @top_level
call-seq:
  bla => true or false

moar comment
    COMMENT

    assert_equal "bla => true or false\n", comment.extract_call_seq
  end

  def test_extract_call_seq_blank
    comment = RDoc::Comment.new <<-COMMENT, @top_level
call-seq:
  bla => true or false

    COMMENT

    assert_equal "bla => true or false\n", comment.extract_call_seq
  end

  def test_extract_call_seq_commented
    comment = RDoc::Comment.new <<-COMMENT, @top_level
# call-seq:
#   bla => true or false
#
# moar comment
    COMMENT

    assert_nil comment.extract_call_seq
  end

  def test_extract_call_seq_no_blank
    comment = RDoc::Comment.new <<-COMMENT, @top_level
call-seq:
  bla => true or false
    COMMENT

    assert_equal "bla => true or false\n", comment.extract_call_seq
  end

  def test_extract_call_seq_undent
    comment = RDoc::Comment.new <<-COMMENT, @top_level
call-seq:
  bla => true or false
moar comment
    COMMENT

    assert_equal "bla => true or false\nmoar comment\n", comment.extract_call_seq
  end

  def test_extract_call_seq_c
    comment = RDoc::Comment.new <<-COMMENT
call-seq:
  commercial() -> Date <br />
  commercial(cwyear, cweek=41, cwday=5, sg=nil) -> Date [ruby 1.8] <br />
  commercial(cwyear, cweek=1, cwday=1, sg=nil) -> Date [ruby 1.9]

If no arguments are given:
* ruby 1.8: returns a +Date+ for 1582-10-15 (the Day of Calendar Reform in
  Italy)
* ruby 1.9: returns a +Date+ for julian day 0

Otherwise, returns a +Date+ for the commercial week year, commercial week,
and commercial week day given. Ignores the 4th argument.
    COMMENT

    expected = <<-CALL_SEQ.chomp
commercial() -> Date <br />
commercial(cwyear, cweek=41, cwday=5, sg=nil) -> Date [ruby 1.8] <br />
commercial(cwyear, cweek=1, cwday=1, sg=nil) -> Date [ruby 1.9]

    CALL_SEQ

    assert_equal expected, comment.extract_call_seq
  end

  def test_extract_call_seq_c_no_blank
    comment = RDoc::Comment.new <<-COMMENT
call-seq:
  commercial() -> Date <br />
  commercial(cwyear, cweek=41, cwday=5, sg=nil) -> Date [ruby 1.8] <br />
  commercial(cwyear, cweek=1, cwday=1, sg=nil) -> Date [ruby 1.9]
    COMMENT

    expected = <<-CALL_SEQ.chomp
commercial() -> Date <br />
commercial(cwyear, cweek=41, cwday=5, sg=nil) -> Date [ruby 1.8] <br />
commercial(cwyear, cweek=1, cwday=1, sg=nil) -> Date [ruby 1.9]

    CALL_SEQ

    assert_equal expected, comment.extract_call_seq
  end

  def test_extract_call_seq_c_separator
    comment = RDoc::Comment.new <<-'COMMENT'
call-seq:
   ARGF.readlines(sep=$/)     -> array
   ARGF.readlines(limit)      -> array
   ARGF.readlines(sep, limit) -> array

   ARGF.to_a(sep=$/)     -> array
   ARGF.to_a(limit)      -> array
   ARGF.to_a(sep, limit) -> array

Reads +ARGF+'s current file in its entirety, returning an +Array+ of its
lines, one line per element. Lines are assumed to be separated by _sep_.

   lines = ARGF.readlines
   lines[0]                #=> "This is line one\n"

    COMMENT

    expected = <<-CALL_SEQ
ARGF.readlines(sep=$/)     -> array
ARGF.readlines(limit)      -> array
ARGF.readlines(sep, limit) -> array
ARGF.to_a(sep=$/)     -> array
ARGF.to_a(limit)      -> array
ARGF.to_a(sep, limit) -> array
    CALL_SEQ

    assert_equal expected, comment.extract_call_seq

    expected = <<-'COMMENT'

Reads +ARGF+'s current file in its entirety, returning an +Array+ of its
lines, one line per element. Lines are assumed to be separated by _sep_.

   lines = ARGF.readlines
   lines[0]                #=> "This is line one\n"

    COMMENT

    assert_equal expected, comment.text
  end

  # This test relies on AnyMethod#call_seq's behaviour as well
  def test_extract_call_linear_performance
    pre = ->(n) {[n, RDoc::Comment.new("\n"*n + 'call-seq:' + 'a'*n)]}
    method_obj = RDoc::AnyMethod.new nil, 'blah'
    assert_linear_performance((2..5).map {|i| 10**i}, pre: pre) do |n, comment|
      method_obj.call_seq = comment.extract_call_seq
      assert_equal n, method_obj.call_seq.size
    end
  end

  def test_force_encoding
    @comment = RDoc::Encoding.change_encoding @comment, Encoding::UTF_8

    assert_equal Encoding::UTF_8, @comment.text.encoding
  end

  def test_format
    assert_equal 'rdoc', @comment.format
  end

  def test_format_equals
    c = comment 'content'
    document = c.parse

    c.format = RDoc::RD

    assert_equal RDoc::RD, c.format
    refute_same document, c.parse
  end

  def test_initialize_copy
    copy = @comment.dup

    refute_same @comment.text, copy.text
    assert_same @comment.location, copy.location
  end

  def test_location
    assert_equal @top_level, @comment.location
  end

  def test_normalize
    @comment.text = <<-TEXT
  # comment
    TEXT
    @comment.language = :ruby

    assert_same @comment, @comment.normalize

    assert_equal 'comment', @comment.text
  end

  def test_normalize_twice
    @comment.text = <<-TEXT
  # comment
    TEXT

    @comment.normalize

    text = @comment.text

    @comment.normalize

    assert_same text, @comment.text, 'normalize not cached'
  end

  def test_normalize_document
    @comment.text = nil
    @comment.document = @RM::Document.new

    assert_same @comment, @comment.normalize

    assert_nil @comment.text
  end

  def test_normalize_eh
    refute @comment.normalized?

    @comment.normalize

    assert @comment.normalized?
  end

  def test_text
    assert_equal 'this is a comment', @comment.text
  end

  def test_text_equals
    @comment.text = 'other'

    assert_equal 'other', @comment.text
    refute @comment.normalized?
  end

  def test_text_equals_no_text
    c = RDoc::Comment.new nil, @top_level
    c.document = @RM::Document.new

    e = assert_raise RDoc::Error do
      c.text = 'other'
    end

    assert_equal 'replacing document-only comment is not allowed', e.message
  end

  def test_text_equals_parsed
    document = @comment.parse

    @comment.text = 'other'

    refute_equal document, @comment.parse
  end

  def test_tomdoc_eh
    refute @comment.tomdoc?

    @comment.format = 'tomdoc'

    assert @comment.tomdoc?
  end

  def test_parse
    parsed = @comment.parse

    expected = @RM::Document.new(
      @RM::Paragraph.new('this is a comment'))

    expected.file = @top_level

    assert_equal expected, parsed
    assert_same  parsed, @comment.parse
  end

  def test_parse_rd
    c = comment 'it ((*works*))'
    c.format = 'rd'

    expected =
      @RM::Document.new(
        @RM::Paragraph.new('it <em>works</em>'))
    expected.file = @top_level

    assert_equal expected, c.parse
  end

  def test_remove_private_encoding
    comment = RDoc::Comment.new <<-EOS, @top_level
# This is text
#--
# this is private
    EOS

    comment = RDoc::Encoding.change_encoding comment, Encoding::IBM437

    comment.remove_private

    assert_equal Encoding::IBM437, comment.text.encoding
  end

  def test_remove_private_hash
    @comment.text = <<-TEXT
#--
# private
#++
# public
    TEXT

    @comment.remove_private

    assert_equal "# public\n", @comment.text
  end

  def test_remove_private_hash_trail
    comment = RDoc::Comment.new <<-EOS, @top_level
# This is text
#--
# this is private
    EOS

    expected = RDoc::Comment.new <<-EOS, @top_level
# This is text
    EOS

    comment.remove_private

    assert_equal expected, comment
  end

  def test_remove_private_long
    comment = RDoc::Comment.new <<-EOS, @top_level
#-----
#++
# this is text
#-----
    EOS

    expected = RDoc::Comment.new <<-EOS, @top_level
# this is text
    EOS

    comment.remove_private

    assert_equal expected, comment
  end

  def test_remove_private_rule
    comment = RDoc::Comment.new <<-EOS, @top_level
# This is text with a rule:
# ---
# this is also text
    EOS

    expected = comment.dup

    comment.remove_private

    assert_equal expected, comment
  end

  def test_remove_private_star
    @comment.text = <<-TEXT
/*
 *--
 * private
 *++
 * public
 */
    TEXT

    @comment.remove_private

    assert_equal "/*\n * public\n */\n", @comment.text
  end

  def test_remove_private_star2
    @comment.text = <<-TEXT
/*--
 * private
 *++
 * public
 */
    TEXT

    @comment.remove_private

    assert_equal "/*--\n * private\n *++\n * public\n */\n", @comment.text
  end

  def test_remove_private_toggle
    comment = RDoc::Comment.new <<-EOS, @top_level
# This is text
#--
# this is private
#++
# This is text again.
    EOS

    expected = RDoc::Comment.new <<-EOS, @top_level
# This is text
# This is text again.
    EOS

    comment.remove_private

    assert_equal expected, comment
  end

  def test_remove_private_toggle_encoding
    comment = RDoc::Comment.new <<-EOS, @top_level
# This is text
#--
# this is private
#++
# This is text again.
    EOS

    comment = RDoc::Encoding.change_encoding comment, Encoding::IBM437

    comment.remove_private

    assert_equal Encoding::IBM437, comment.text.encoding
  end

  def test_remove_private_toggle_encoding_ruby_bug?
    comment = RDoc::Comment.new <<-EOS, @top_level
#--
# this is private
#++
# This is text again.
    EOS

    comment = RDoc::Encoding.change_encoding comment, Encoding::IBM437

    comment.remove_private

    assert_equal Encoding::IBM437, comment.text.encoding
  end

end
