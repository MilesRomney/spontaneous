require 'test_helper'


class PageTest < Test::Unit::TestCase
  include Spontaneous

  context "Root page" do
    setup do
      Content.delete
    end
    should "be created by first page insert" do
      p = Page.create
      p.root?.should be_true
      p.path.should == "/"
      p.slug.should == ""
      p.parent.should be_nil
    end

    should "be a singleton" do
      p = Page.create
      p.root?.should be_true
      q = Page.create
      q.root?.should be_false
    end
  end

  context "Slugs" do
    setup do
    end

    should "be generated if missing" do
      p = Page.new
      p.slug.should_not == ""
    end

    should "be made URL safe" do
      p = Page.new
      p.slug = " something's illegal and ugly!!"
      p.slug.should == "somethings-illegal-and-ugly"
      p.save
      p.reload.slug.should == "somethings-illegal-and-ugly"
    end
  end

  context "Pages in tree" do
    setup do
      Content.delete
      @p = Page.create
      @p.root?.should be_true
      @q = Page.new
      @r = Page.new
      @s = Page.new
      @t = Page.new
      @p << @q
      @q << @r
      @q << @s
      @s << @t
      @p.save
      @q.save
      @r.save
      @s.save
      @t.save
      # doing this means that the == tests work below
      @p = Page[@p.id]
      @q = Page[@q.id]
      @r = Page[@r.id]
      @s = Page[@s.id]
      @t = Page[@t.id]
    end

    should "have the right entry classes" do
      @p.entries.first.proxy_class.should == Spontaneous::PageEntry
      @q.entries.first.proxy_class.should == Spontaneous::PageEntry
      @s.entries.first.proxy_class.should == Spontaneous::PageEntry
    end

    should "have a reference to their parent" do
      @p.parent.should be_nil
      @q.parent.should === @p
      @r.parent.should === @q
      @s.parent.should === @q
      @t.parent.should === @s
    end
    should "have a list of their children" do
      @p.children.should == [@q]
      @q.children.should == [@r, @s]
      @r.children.should == []
      @s.children.should == [@t]
      @t.children.should == []
    end
    should "keep track of their depth" do
      @p.depth.should == 0
      @q.depth.should == 1
      @r.depth.should == 2
      @s.depth.should == 2
      @t.depth.should == 3
    end

    should "have correct paths" do
      @p.path.should == "/"
      @q.path.should == "/#{@q.slug}"
      @r.path.should == "/#{@q.slug}/#{@r.slug}"
      @s.path.should == "/#{@q.slug}/#{@s.slug}"
      @t.path.should == "/#{@q.slug}/#{@s.slug}/#{@t.slug}"
    end

    should "all have a reference to the root node" do
      # @p.root?.should be_true
      @p.root.should === @p
      @q.root.should === @p
      @r.root.should === @p
      @s.root.should === @p
      @t.root.should === @p
    end

    should "know their ancestors" do
      # must be a better way to test these arrays
      @p.ancestors.should === []
      @q.ancestors.should === [@p]
      @r.ancestors.should == [@q, @p]
      @s.ancestors.should == [@q, @p]
      @t.ancestors.should === [@s, @q, @p]
    end

    should "know their generation" do
      @r.generation.should == [@r, @s]
      @s.generation.should == [@r, @s]
    end

    should "know their siblings" do
      @r.siblings.should == [@s]
      @s.siblings.should == [@r]
    end

    should "always have the right path" do
      @q.slug = "changed"
      @q.save
      @p.reload.path.should == "/"
      @q.reload.path.should == "/changed"
      @r.reload.path.should == "/changed/#{@r.slug}"
      @s.reload.path.should == "/changed/#{@s.slug}"
      @t.reload.path.should == "/changed/#{@s.slug}/#{@t.slug}"
    end
  end

  context "page entries" do
    setup do
      @parent = Page.create
      @facet = Facet.new
      @child = Page.new
      @parent << @facet
      @facet << @child
      @parent.save
      @facet.save
      @child.save
    end

    should "report their depth according to their position in the facet tree" do
      @parent.depth.should == 0
      @parent.entries.first.depth.should == 1
      @parent.entries.first.entries.first.depth.should == 2
    end
  end

  context "page templates" do
    setup do
      class ::PageClass < Page; end
      PageClass.page_style :standard_style
      PageClass.page_style :other, :title => "Custom Title"
    end
    teardown do
      Object.send(:remove_const, :PageClass)
    end

    should "be definable" do
      PageClass.page_styles.length.should == 2
    end

    should "be an instance of Style" do
      PageClass.page_styles.first.class.should == Style
    end
    should "have a name" do
      PageClass.page_styles.first.name.should == :standard_style
    end

    should "be accessible by name" do
      PageClass.page_styles[:other].name.should == :other
    end

    should "choose the first defined template as the default unless told otherwise" do
      PageClass.page_styles.default.name.should == :standard_style
    end

    should "use defined default style if existant" do
      PageClass.page_style :new_default, :default => true
      PageClass.page_styles.default.name.should == :new_default
    end

    should "take filename from name by default" do
      PageClass.page_styles[:other].filename.should == "other.html.erb"
    end

    should "have configurable filenames" do
      PageClass.page_style :custom, :filename => "funky"
      PageClass.page_styles[:custom].filename.should == "funky.html.erb"
    end

    should "have sane default titles" do
      PageClass.page_styles[:standard_style].title.should == "Standard Style"
    end

    should "have configurable titles" do
      PageClass.page_styles[:other].title.should == "Custom Title"
    end

    should "automatically set the Page#style_id attribute to the default style on creation" do
      p = PageClass.new
      p.style.should == PageClass.page_styles.default
    end

    should "persist the chosen page style" do
      p = PageClass.new
      p.style = PageClass.page_styles[:other]
      p.save
      p = PageClass[p.id]
      p.style.should == PageClass.page_styles[:other]
    end
  end

  context "pages as inline content" do

    setup do
      class ::PageClass < Page; end
      class ::FacetClass < Facet; end
      PageClass.page_style :page_style
      PageClass.inline_style :inline_style
      @parent = Page.new
      @facet = Facet.new
      @page = PageClass.new
      @parent << @facet
      @facet << @page
      @parent.save
      @facet.save
      @page.save
    end
    teardown do
      Object.send(:remove_const, :PageClass)
      Object.send(:remove_const, :FacetClass)
    end
    should "use style assigned by entry" do
      @parent.entries.first.entries.first.style.should == PageClass.inline_styles.default
    end

    should "use their default page style when accessed directly" do
      @page = PageClass[@page.id]
      @page.style.should == PageClass.page_styles.default
    end

    should "persist sub-page style settings" do
      @parent = Page[@parent.id]
      @parent.entries.first.entries.first.style.should == PageClass.inline_styles.default
    end
  end
  # context ""
end