# -*- coding: utf-8 -*-
#
# Copyright (C) 2009-2013  Kouhei Sutou <kou@clear-code.com>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License version 2.1 as published by the Free Software Foundation.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

class IndexColumnTest < Test::Unit::TestCase
  include GroongaTestUtils

  def setup
    setup_database
  end

  class PredicateTest < self
    def setup
      super
      setup_index
    end

    def setup_index
      articles = Groonga::Array.create(:name => "Articles")
      articles.define_column("content", "Text")

      terms = Groonga::Hash.create(:name => "Terms",
                                   :key_type => "ShortText",
                                   :default_tokenizer => "TokenBigram")
      @index = terms.define_index_column("content", articles,
                                         :with_section => true)
    end

    def test_index?
      assert_predicate(@index, :index?)
    end

    def test_vector?
      assert_not_predicate(@index, :vector?)
    end

    def test_scalar?
      assert_not_predicate(@index, :scalar?)
    end
  end

  class CRUDTest < self
    setup
    def setup_schema
      @articles = Groonga::Array.create(:name => "Articles")
      @articles.define_column("content", "Text")

      terms = Groonga::Hash.create(:name => "Terms",
                                   :key_type => "ShortText",
                                   :default_tokenizer => "TokenBigram")
      @index = terms.define_index_column("content", @articles,
                                         :with_position => true,
                                         :with_section => true)
    end

    def test_array_set_with_record
      content = <<-EOC
      groonga は組み込み型の全文検索エンジンライブラリです。
      DBMSやスクリプト言語処理系等に組み込むことによって、その
      全文検索機能を強化することができます。また、リレーショナ
      ルモデルに基づくデータストア機能を内包しており、groonga
      単体でも高速なデータストアサーバとして使用することができ
      ます。

      ■全文検索方式
      転置索引型の全文検索エンジンです。転置索引は圧縮されてファ
      イルに格納され、検索時のディスク読み出し量を小さく、かつ
      局所的に抑えるように設計されています。用途に応じて以下の
      索引タイプを選択できます。
      EOC

      groonga = @articles.add(:content => content)

      content.split(/\n{2,}/).each_with_index do |sentence, i|
        @index[groonga] = {:value => sentence, :section => i + 1}
      end
      assert_equal([groonga],
                   @index.search("エンジン").collect {|record| record.key})
    end

    def test_add
      content = <<-CONTENT
      Groonga is a fast and accurate full text search engine based on
      inverted index. One of the characteristics of groonga is that a
      newly registered document instantly appears in search
      results. Also, groonga allows updates without read locks. These
      characteristics result in superior performance on real-time
      applications.

      Groonga is also a column-oriented database management system
      (DBMS). Compared with well-known row-oriented systems, such as
      MySQL and PostgreSQL, column-oriented systems are more suited for
      aggregate queries. Due to this advantage, groonga can cover
      weakness of row-oriented systems.

      The basic functions of groonga are provided in a C library. Also,
      libraries for using groonga in other languages, such as Ruby, are
      provided by related projects. In addition, groonga-based storage
      engines are provided for MySQL and PostgreSQL. These libraries
      and storage engines allow any application to use groonga. See
      usage examples.
      CONTENT

      groonga = @articles.add(:content => content)

      content.split(/\n{2,}/).each_with_index do |sentence, i|
        @index.add(groonga, sentence, :section => i + 1)
      end
      assert_equal([groonga], @index.search("engine").collect(&:key))
    end

    def test_delete
      content = <<-CONTENT
      Groonga is a fast and accurate full text search engine based on
      inverted index. One of the characteristics of groonga is that a
      newly registered document instantly appears in search
      results. Also, groonga allows updates without read locks. These
      characteristics result in superior performance on real-time
      applications.

      Groonga is also a column-oriented database management system
      (DBMS). Compared with well-known row-oriented systems, such as
      MySQL and PostgreSQL, column-oriented systems are more suited for
      aggregate queries. Due to this advantage, groonga can cover
      weakness of row-oriented systems.

      The basic functions of groonga are provided in a C library. Also,
      libraries for using groonga in other languages, such as Ruby, are
      provided by related projects. In addition, groonga-based storage
      engines are provided for MySQL and PostgreSQL. These libraries
      and storage engines allow any application to use groonga. See
      usage examples.
      CONTENT

      groonga = @articles.add(:content => content)

      content.split(/\n{2,}/).each_with_index do |sentence, i|
        @index.add(groonga, sentence, :section => i + 1)
      end
      content.split(/\n{2,}/).each_with_index do |sentence, i|
        @index.delete(groonga, sentence, :section => i + 1)
      end
      assert_equal([], @index.search("engine").collect(&:key))
    end

    def test_update
      old_sentence = <<-SENTENCE
      Groonga is a fast and accurate full text search engine based on
      inverted index. One of the characteristics of groonga is that a
      newly registered document instantly appears in search
      results. Also, groonga allows updates without read locks. These
      characteristics result in superior performance on real-time
      applications.
      SENTENCE

      new_sentence = <<-SENTENCE
      Groonga is also a column-oriented database management system
      (DBMS). Compared with well-known row-oriented systems, such as
      MySQL and PostgreSQL, column-oriented systems are more suited for
      aggregate queries. Due to this advantage, groonga can cover
      weakness of row-oriented systems.
      SENTENCE

      groonga = @articles.add(:content => old_sentence)

      @index.add(groonga, old_sentence, :section => 1)
      assert_equal([groonga],
                   @index.search("engine").collect(&:key))
      assert_equal([],
                   @index.search("MySQL").collect(&:key))

      groonga[:content] = new_sentence
      @index.update(groonga, old_sentence, new_sentence, :section => 1)
      assert_equal([],
                   @index.search("engine").collect(&:key))
      assert_equal([groonga],
                   @index.search("MySQL").collect(&:key))
    end
  end

  class NGramTest < self
  def test_shorter_query_than_ngram
    articles = Groonga::Array.create(:name => "Articles")
    articles.define_column("content", "Text")

    terms = Groonga::PatriciaTrie.create(:name => "Terms",
                                         :default_tokenizer => "TokenBigram")
    content_index = terms.define_index_column("content", articles,
                                              :source => "Articles.content")
    articles.add(:content => 'l')
    articles.add(:content => 'll')
    articles.add(:content => 'hello')

    assert_search(["hello"], content_index, "he")
    assert_search(["ll", "hello"], content_index, "ll")
    assert_search(["l", "ll", "hello"], content_index, "l")
  end
  end

  class FlagTest < self
    def setup
      super
      define_table
    end

    def define_table
      Groonga::Schema.define do |schema|
        schema.create_table("Articles") do |table|
          table.text("tags", :type => :vector)
        end
      end
    end

    def test_with_section?
      Groonga::Schema.define do |schema|
        schema.create_table("Tags",
                            :type => :patricia_trie,
                            :key_type => "ShortText",
                            :default_tokenizer => "TokenDelimit") do |table|
          table.index("Articles.tags",
                      :name => "section",
                      :with_section => true)
          table.index("Articles.tags",
                      :name => "no_section")
        end
      end

      assert_equal([
                     true,
                     false,
                   ],
                   [
                     context["Tags.section"].with_section?,
                     context["Tags.no_section"].with_section?,
                   ])
    end

    def test_with_weight?
      Groonga::Schema.define do |schema|
        schema.create_table("Tags",
                            :type => :patricia_trie,
                            :key_type => "ShortText",
                            :default_tokenizer => "TokenDelimit") do |table|
          table.index("Articles.tags",
                      :name => "weight",
                      :with_weight => true)
          table.index("Articles.tags",
                      :name => "no_weight")
        end
      end

      assert_equal([
                     true,
                     false,
                   ],
                   [
                     context["Tags.weight"].with_weight?,
                     context["Tags.no_weight"].with_weight?,
                   ])
    end

    def test_with_position?
      Groonga::Schema.define do |schema|
        schema.create_table("Tags",
                            :type => :patricia_trie,
                            :key_type => "ShortText",
                            :default_tokenizer => "TokenDelimit") do |table|
          table.index("Articles.tags",
                      :name => "position",
                      :with_position => true)
          table.index("Articles.tags",
                      :name => "no_position")
        end
      end

      assert_equal([
                     true,
                     false,
                   ],
                   [
                     context["Tags.position"].with_position?,
                     context["Tags.no_position"].with_position?,
                   ])
    end
  end

  private
  def assert_search(expected, content_index, keyword)
    result = content_index.search(keyword).collect do |entry|
      entry.key["content"]
    end
    assert_equal(expected, result)
  end
end
