# encoding: UTF-8

require 'test_helper'


class PublishingTest < Test::Unit::TestCase

  def assert_content_equal(result, compare)
    serialised_columns = [:field_store, :entry_store]
    columns = Content.columns - serialised_columns
    columns.each do |col|
      # result[col].should == compare[col]
      assert_equal(result[col], compare[col], "Column '#{col}' should be equal")
    end
    serialised_columns.each do |col|
      result.send(col).should == compare.send(col)
    end
  end

  context "publishing" do

    setup do
      Spontaneous.database = DB

      # DB.logger = Logger.new($stdout)
      Content.delete

      2.times do |i|
        c = Page.new(:uid => i)
        2.times do |j|
          d = Content.new(:uid => "#{i}.#{j}")
          c << d
          2.times do |k|
            d << Page.new(:uid => "#{i}.#{j}.#{k}")
            d.save
          end
        end
        c.save
      end
    end

    teardown do
      Content.delete_all_revisions!
      Content.delete
      DB.logger = nil
    end

    context "data sources" do

      should "have the right names" do
        Content.revision_table(23).should == '__r00023_content'
        Content.revision_table(nil).should == 'content'
      end

      should "be recognisable" do
        Content.revision_table?('content').should be_false
        Content.revision_table?('__r00023_content').should be_true
        Content.revision_table?('__r00023_not').should be_false
        Content.revision_table?('subscribers').should be_false
      end

      should "be switchable within blocks" do
        Content.dataset.should be_content_revision
        Content.with_revision(23) do
          Content.revision.should ==23
          Content.dataset.should be_content_revision(23)
        end
        Content.dataset.should  be_content_revision
        Content.revision.should be_nil
      end

      should "know which revision is active" do
        Content.with_revision(23) do
          Content.revision.should == 23
        end
      end

      should "be switchable without blocks" do
        Content.with_revision(23)
        Content.dataset.should be_content_revision(23)
        Content.reset_revision
        Content.dataset.should be_content_revision
      end

      should "understand the with_editable" do
        Content.with_revision(23) do
          Content.dataset.should be_content_revision(23)
          Content.with_editable do
            Content.dataset.should be_content_revision
          end
          Content.dataset.should be_content_revision(23)
        end
        Content.dataset.should be_content_revision
      end

      should "understand with_published" do
        Site.stubs(:published_revision).returns(99)
        Content.with_published do
          Content.dataset.should be_content_revision(99)
          Content.with_editable do
            Content.dataset.should be_content_revision
          end
          Content.dataset.should be_content_revision(99)
        end
        Content.dataset.should be_content_revision
      end

      should "be stackable" do
        Content.dataset.should be_content_revision
        Content.with_revision(23) do
          Content.dataset.should be_content_revision(23)
          Content.with_revision(24) do
            Content.dataset.should be_content_revision(24)
          end
          Content.dataset.should be_content_revision(23)
        end
        Content.dataset.should be_content_revision
      end

      should "reset datasource after an exception" do
        Content.dataset.should be_content_revision
        begin
          Content.with_revision(23) do
            Content.dataset.should be_content_revision(23)
            raise Exception.new
          end
        rescue Exception
        end
        Content.dataset.should be_content_revision
      end

      context "subclasses" do
        setup do
          class ::Subclass < Page; end
        end

        teardown do
          Object.send(:remove_const, :Subclass)
        end

        should "set all subclasses to use the same dataset" do
          Content.with_revision(23) do
            Subclass.revision.should ==23
            Subclass.dataset.should be_content_revision(23, 'Subclass')
            # facet wasn't loaded until this point
            Facet.dataset.should  be_content_revision(23, 'Spontaneous::Facet')
            Facet.revision.should == 23
          end
          Subclass.dataset.should  be_content_revision(nil, 'Subclass')
          Facet.dataset.should  be_content_revision(nil, 'Spontaneous::Facet')
        end
      end
    end

    context "content revisions" do
      setup do
        @now = Sequel.datetime_class.now
        Sequel.datetime_class.stubs(:now).returns(@now)
      end
      should "be testable for existance" do
        revision = 1
        Content.revision_exists?(revision).should be_false
        Content.create_revision(revision)
        Content.revision_exists?(revision).should be_true
      end
      should "be deletable en masse" do
        tables = (1..10).map { |i| Content.revision_table(i).to_sym }
        tables.each do |t|
          DB.create_table(t){Integer :id}
        end
        tables.each do |t|
          DB.tables.include?(t).should be_true
        end
        Content.delete_all_revisions!
        tables.each do |t|
          DB.tables.include?(t).should be_false
        end
      end

      should "be creatable from current content" do
        revision = 1
        DB.tables.include?(Content.revision_table(revision).to_sym).should be_false
        Content.create_revision(revision)
        DB.tables.include?(Content.revision_table(revision).to_sym).should be_true
        count = Content.count
        Content.with_revision(revision) do
          Content.count.should == count
          Content.all.each do |published|
            Content.with_editable do
              e = Content[published.id]
              e.should == published
            end
          end
        end
      end

      should "be creatable from any revision" do
        revision = 2
        source_revision = 1
        source_revision_count = nil

        Content.create_revision(source_revision)

        Content.with_revision(source_revision) do
          Content.filter(:depth => 0).limit(1).each do |c|
            c.destroy
          end
          source_revision_count = Content.count
        end

        Content.count.should == source_revision_count + 7

        Content.create_revision(revision, source_revision)

        Content.with_revision(revision) do
          Content.count.should == source_revision_count
          Content.all.each do |published|
            Content.with_revision(source_revision) do
              e = Content[published.id]
              e.should == published
            end
          end
        end
      end

      should "have the correct indexes" do
        revision = 1
        Content.create_revision(revision)
        content_indexes = DB.indexes(:content)
        published_indexes = DB.indexes(Content.revision_table(revision))
        # made slightly complex by the fact that the index names depend on the table names
        # (which are different)
        assert_same_elements published_indexes.values, content_indexes.values
      end


      context "incremental publishing" do
        setup do
          @initial_revision = 1
          @final_revision = 2
          Content.create_revision(@initial_revision)
          # DB.logger = Logger.new($stdout)
        end

        teardown do
          DB.logger = nil
        end

        should "duplicate changes to only a single item" do
          editable1 = Content.first(:uid => '1.0')
          editable1.label.should be_nil
          editable1.label = "published"
          editable1.save
          editable1.reload
          editable2 = Content.first(:uid => '1.1')
          editable2.label = "unpublished"
          editable2.save
          # editable2.reload
          Content.publish(@final_revision, [editable1.id])

          Content.with_revision(@final_revision) do
            published = Content[editable1.id]
            unpublished = Content[editable2.id]
            assert_content_equal(published, editable1)
            # published.should == editable1
            unpublished.should_not == editable2
          end
        end

        should "publish additions to contents of a page" do
          editable1 = Content.first(:uid => '0')
          new_content = Content.new(:uid => "new")

          editable1 << new_content
          editable1.save
          new_content.reload
          editable1.reload
          Content.publish(@final_revision, [editable1.id])
          Content.with_revision(@final_revision) do
            published1 = Content[editable1.id]
            published2 = Content[new_content.id]
            # published2.should == new_content
            assert_content_equal(published2, new_content)
            # published1.should == editable1
            assert_content_equal(published1, editable1)
          end
        end

        should "publish deletions to contents of page" do
          editable1 = Content.first(:uid => '0')
          deleted = editable1.entries.first.target
          editable1.entries.first.destroy
          editable1.reload
          Content.publish(@final_revision, [editable1.id])
          Content.with_revision(@final_revision) do
            published1 = Content[editable1.id]
            assert_content_equal(published1, editable1)
            # published1.should == editable1
            Content[deleted.id].should be_nil
          end
        end

        should "publish page additions" do
          editable1 = Content.first(:uid => '0')
          new_page = Page.new(:uid => "new")
          slot = editable1.entries.first
          slot << new_page
          editable1.save
          slot.save
          new_page.save
          new_page.reload
          editable1.reload
          slot.reload
          Content.publish(@final_revision, [editable1.id])
          Content.with_revision(@final_revision) do
            published1 = Content[editable1.id]
            published2 = Content[new_page.id]
            published3 = Content[slot.id]
            # published1.should == editable1
            assert_content_equal(published1, editable1)
            # published2.should == new_page
            assert_content_equal(published2, new_page)
            # published3.should == slot
            assert_content_equal(published3, slot.target)
          end
        end

        should "not publish changes to existing pages unless explicitly asked" do
          editable1 = Content.first(:uid => '0')
          editable1 << Content.new(:uid => "added")
          editable1.save
          editable1.reload
          editable2 = Content.first(:uid => '0.0.0')
          new_content = Content.new(:uid => "new")
          editable2 << new_content
          editable2.save
          editable2.reload
          new_content.reload
          Content.publish(@final_revision, [editable1.id])
          Content.with_revision(@final_revision) do
            published1 = Content[editable1.id]
            Content.first(:uid => "added").should_not be_nil
            published3 = Content[editable2.id]
            assert_content_equal(published1, editable1)
            # published1.should == editable1
            published3.should_not == editable2
            published3.uid.should_not == "new"
          end
          Content.publish(@final_revision+1, [editable2.id])
          Content.with_revision(@final_revision+1) do
            published1 = Content[editable1.id]
            # published1.should == editable1
            assert_content_equal(published1, editable1)
            assert_content_equal(published1, editable1)
            published3 = Content[editable2.id]
            # published3.should == editable2
            assert_content_equal(published3, editable2)
            published4 = Content[editable2.entries.first.id]
            # published4.should == editable2.entries.first
            assert_content_equal(published4, editable2.entries.first)
          end
        end
      end


    end

    context "modification timestamps" do
      setup do
        @now = Sequel.datetime_class.now
        Sequel.datetime_class.stubs(:now).returns(@now)
      end
      should "register creation date of all content" do
        c = Content.create
        c.created_at.should == @now
        p = Page.create
        p.created_at.should == @now
      end

      should "register modification date of all content" do
        now = @now + 100
        Time.stubs(:now).returns(now)
        c = Content.first
        c.modified_at.to_i.should == @now.to_i
        c.label = "changed"
        c.save
        c.modified_at.should == now
      end

      should "update page timestamps on modification of a facet" do
        Sequel.datetime_class.stubs(:now).returns(@now+3600)
        page = Page.first
        page.modified_at.to_i.should == @now.to_i
        content = page.entries.first
        content.page.should == page
        content.label = "changed"
        content.save
        page.reload
        page.modified_at.to_i.should == @now.to_i + 3600
      end

      should "update page timestamp on addition of facet" do
        Sequel.datetime_class.stubs(:now).returns(@now+3600)
        page = Page.first
        content = Content[page.entries.first.id]
        content << Content.new
        content.save
        content.modified_at.to_i.should == @now.to_i + 3600
        page.reload
        page.modified_at.to_i.should == @now.to_i + 3600
      end
    end

    context "change sets" do
      setup do
        Change.delete
        @now = Sequel.datetime_class.now
        Sequel.datetime_class.stubs(:now).returns(@now)
        Time.stubs(:now).returns(@now)
      end

      should "have a testable state" do
        Change.recording?.should be_false
        Change.record do
          Change.recording?.should be_true
        end
        Change.recording?.should be_false
      end
      should "be created on updating a page's attributes" do
        page = Page.first
        Change.record do
          page.label = "changed"
          page.save
        end
        page.reload
        Change.count.should == 1
        change = Change.first
        change.modified_list.should be_instance_of(Array)
        change.modified_list.length.should == 1
        change.modified_list.should == [page.id]
        change.modified.should == [page]
        change.created_at.to_i.should == @now.to_i
      end

      should "be created on updating a page's content" do
        page = Page.first
        content = Content[page.entries.first.target.id]
        Change.record do
          content.label = "changed"
          content.save
        end
        page.reload
        Change.count.should == 1
        change = Change.first
        change.modified_list.should be_instance_of(Array)
        change.modified_list.length.should == 1
        change.modified_list.should == [page.id]
        change.modified.should == [page]
      end

      should "include all modified pages" do
        page = Page.first
        content = Content[page.entries.first.target.id]
        new_page = nil
        Change.record do
          new_page = Page.new
          content << new_page
          content.save
        end
        new_page.reload
        page.reload
        Change.count.should == 1
        change = Change.first
        change.modified_list.should be_instance_of(Array)
        change.modified_list.length.should == 2
        change.modified_list.should == [page.id, new_page.id]
        change.modified.should == [page, new_page]
      end
      should "handle being called twice" do
        page = Page.first
        p2 = Page.filter(~{:id => page.id}).first
        Change.record do
          page.label = "changed"
          page.save
          Change.record do
            p2.label = "another change"
            p2.save
          end
        end
        page.reload
        p2.reload
        Change.count.should == 1
        change = Change.first
        change.modified_list.should be_instance_of(Array)
        change.modified_list.length.should == 2
        change.modified_list.should == [page.id, p2.id]
        change.modified.should == [page, p2]
      end

      should "not create a change if nothing actually happens" do
        Change.record do
        end
        Change.count.should == 0
      end

      should "reset state despite exceptions" do
        page = Page.first
        begin
          Change.record do
            page.label = "caught"
            page.save
            Change.recording?.should be_true
            raise Exception.new
          end
        rescue Exception
        end
        Change.recording?.should be_false
        Change.count.should == 1
      end

      should "correctly calculate dependencies" do
        Change.delete
        changes = [
          [201, 202],
          [104, 105, 106],
          [100, 101],
          [100],
          [101],
          [100],
          [101, 102],
          [102],
          [101],
          [102, 103],
          [103, 104],
          [200],
          [200, 201],
          [201]
        ]
        publish_sets = [
          [1, 13, 14, 12],
          [2, 11, 8, 10, 3, 4, 5, 6, 7, 9]
        ]
        changes.each_with_index do |ids, i|
          Change.insert(:id => (i+1), :modified_list => ids.to_json)
        end
        result = Change.publish_sets
        result.should be_instance_of(Array)
        result.length.should == 2
        result.each_with_index do |set, i|
          set.should == publish_sets[i].map { |id| Change[id] }
        end
      end
    end

    context "publication timestamps" do
      setup do
        @revision = 1
        @now = Sequel.datetime_class.now
        Sequel.datetime_class.stubs(:now).returns(@now)
      end

      should "set correct timestamps on first publish" do
        Content.first.first_published_at.should be_nil
        Content.first.last_published_at.should be_nil
        Content.publish(@revision)
        Content.first.first_published_at.to_i.should == @now.to_i
        Content.first.last_published_at.to_i.should == @now.to_i
        Content.first.first_published_revision.should == @revision
        Content.with_revision(@revision) do
          Content.first.first_published_at.to_i.should == @now.to_i
          Content.first.last_published_at.to_i.should == @now.to_i
          Content.first.first_published_revision.should == @revision
        end
      end

      should "set correct timestamps on later publishes" do
        Content.first.first_published_at.should be_nil
        Content.publish(@revision)
        Content.first.first_published_at.to_i.should == @now.to_i
        c = Content.create
        c.first_published_at.should be_nil
        Sequel.datetime_class.stubs(:now).returns(@now+100)
        Content.publish(@revision+1)
        Content.first.first_published_at.to_i.should == @now.to_i
        Content.first.last_published_at.to_i.should == @now.to_i + 100
        c = Content[c.id]
        c.first_published_at.to_i.should == @now.to_i + 100
      end

      should "not set publishing date for items not published" do
        Content.publish(@revision)
        page = Content.first
        page.uid = "fish"
        page.save
        added = Content.create
        added.first_published_at.should be_nil
        Content.publish(@revision+1, [page])
        page.first_published_at.to_i.should == @now.to_i
        added.first_published_at.should be_nil
        added.last_published_at.should be_nil
      end
      should "always publish all if no previous revisions exist" do
        page = Content.first
        Content.filter(:first_published_at => nil).count.should == Content.count
        Content.publish(@revision, [page])
        Content.filter(:first_published_at => nil).count.should == 0
      end
    end
  end
end
