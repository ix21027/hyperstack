require "spec_helper"

describe React::Component do
  after(:each) do
    React::API.clear_component_class_cache
  end

  describe "Life Cycle" do
    before(:each) do
      stub_const 'Foo', Class.new
      Foo.class_eval do
        include React::Component
        def render
          React.create_element("div") { "lorem" }
        end
      end
    end

    it "should invoke `before_mount` registered methods when `componentWillMount()`" do
      Foo.class_eval do
        before_mount :bar, :bar2
        def bar; end
        def bar2; end
      end

      expect_any_instance_of(Foo).to receive(:bar)
      expect_any_instance_of(Foo).to receive(:bar2)

      renderToDocument(Foo)
    end

    it "should invoke `after_mount` registered methods when `componentDidMount()`" do
      Foo.class_eval do
        after_mount :bar3, :bar4
        def bar3; end
        def bar4; end
      end

      expect_any_instance_of(Foo).to receive(:bar3)
      expect_any_instance_of(Foo).to receive(:bar4)

      renderToDocument(Foo)
    end

    it "should allow multiple class declared life cycle hooker" do
      stub_const 'FooBar', Class.new
      Foo.class_eval do
        before_mount :bar
        def bar; end
      end

      FooBar.class_eval do
        include React::Component
        after_mount :bar2
        def bar2; end
        def render
          React.create_element("div") { "lorem" }
        end
      end

      expect_any_instance_of(Foo).to receive(:bar)

      renderToDocument(Foo)
    end

    it "should allow block for life cycle helpers" do
      proc_a = Proc.new {}
      proc_b = Proc.new {}
      Foo.class_eval do
        before_mount(&proc_a)
        after_mount(&proc_b)
      end

      expect(proc_a).to receive(:call)
      expect(proc_b).to receive(:call)

      renderToDocument(Foo)
    end
  end

  describe "State setter & getter" do
    before(:each) do
      stub_const 'Foo', Class.new
      Foo.class_eval do
        include React::Component
        def render
          React.create_element("div") { "lorem" }
        end
      end
    end

    it "should define setter using `define_state`" do
      Foo.class_eval do
        define_state :foo
        before_mount :set_up
        def set_up
          self.foo = "bar"
        end
      end

      element = renderToDocument(Foo)
      expect(element.state.foo).to be("bar")
    end

    it "should define init state by passing a block to `define_state`" do
      Foo.class_eval do
        define_state(:foo) { 10 }
      end

      element = renderToDocument(Foo)
      expect(element.state.foo).to be(10)
    end

    it "should define getter using `define_state`" do
      Foo.class_eval do
        define_state(:foo) { 10 }
        before_mount :bump
        def bump
          self.foo = self.foo + 20
        end
      end

      element = renderToDocument(Foo)
      expect(element.state.foo).to be(30)
    end

    it "should define multiple state accessor by passing symols array to `define_state`" do
      Foo.class_eval do
        define_state :foo, :foo2
        before_mount :set_up
        def set_up
          self.foo = 10
          self.foo2 = 20
        end
      end

      element = renderToDocument(Foo)
      expect(element.state.foo).to be(10)
      expect(element.state.foo2).to be(20)
    end

    it "should invoke `define_state` multiple times to define states" do
      Foo.class_eval do
        define_state(:foo) { 30 }
        define_state(:foo2) { 40 }
      end

      element = renderToDocument(Foo)
      expect(element.state.foo).to be(30)
      expect(element.state.foo2).to be(40)
    end

    it "should raise error if multiple states and block given at the same time" do
      expect  {
        Foo.class_eval do
          define_state(:foo, :foo2) { 30 }
        end
      }.to raise_error
    end

    it "should get state in render method" do
      Foo.class_eval do
        define_state(:foo) { 10 }
        def render
          React.create_element("div") { self.foo }
        end
      end

      element = renderToDocument(Foo)
      expect(element.getDOMNode.textContent).to eq("10")
    end

    pending "should set initial state in Class#initialize method" do
      Foo.class_eval do
        define_state :foo, :bar
        def initialize
          self.foo = 10
          self.bar = 20
        end
      end

      element = renderToDocument(Foo)
      expect(element.state.foo).to eq(10)
      expect(element.state.bar).to eq(20)
    end

    pending "should allow getter for initial state in Class#initialize method" do
      Foo.class_eval do
        define_state :foo, :bar
        def initialize
          self.foo = 10
          self.bar = self.foo + 20
        end
      end

      element = renderToDocument(Foo)
      expect(element.state.foo).to eq(10)
      expect(element.state.bar).to eq(30)
    end
  end

  describe "Props" do
    describe "this.props could be accessed through `params` method" do
      before do
        stub_const 'Foo', Class.new
        Foo.class_eval do
          include React::Component
        end
      end

      it "should read from parent passed properties through `params`" do
        Foo.class_eval do
          def render
            React.create_element("div") { params[:prop] }
          end
        end

        element = renderToDocument(Foo, prop: "foobar")
        expect(element.getDOMNode.textContent).to eq("foobar")
      end
    end

    describe "Prop validation" do
      before do
        stub_const 'Foo', Class.new
        Foo.class_eval do
          include React::Component
        end
      end

      it "should specify validation rules using `params` class method" do
        Foo.class_eval do
          params do
            requires :foo, type: String
            optional :bar
          end
        end

        expect(Foo.prop_types).to have_key(:_componentValidator)
      end

      it "should log error in warning if validation failed" do
        stub_const 'Lorem', Class.new
        Foo.class_eval do
          params do
            requires :foo
            requires :lorem, type: Lorem
            optional :bar, type: String
          end

          def render; div; end
        end

        %x{
          var log = [];
          var org_console = window.console;
          window.console = {warn: function(str){log.push(str)}}
        }
        renderToDocument(Foo, bar: 10, lorem: Lorem.new)
        `window.console = org_console;`
        expect(`log`).to eq(["Warning: In component `Foo`\nRequired prop `foo` was not specified\nProvided prop `bar` was not the specified type `String`"])
      end

      it "should not log anything if validation pass" do
        stub_const 'Lorem', Class.new
        Foo.class_eval do
          params do
            requires :foo
            requires :lorem, type: Lorem
            optional :bar, type: String
          end

          def render; div; end
        end

        %x{
          var log = [];
          var org_console = window.console;
          window.console = {warn: function(str){log.push(str)}}
        }
        renderToDocument(Foo, foo: 10, bar: "10", lorem: Lorem.new)
        `window.console = org_console;`
        expect(`log`).to eq([])
      end
    end

    describe "Default props" do
      it "should set default props using validation helper" do
        stub_const 'Foo', Class.new
        Foo.class_eval do
          include React::Component
          params do
            optional :foo, default: "foo"
            optional :bar, default: "bar"
          end

          def render
            div { params[:foo] + "-" + params[:bar]}
          end
        end

        expect(React.render_to_static_markup(React.create_element(Foo, foo: "lorem"))).to eq("<div>lorem-bar</div>")
        expect(React.render_to_static_markup(React.create_element(Foo))).to eq("<div>foo-bar</div>")
      end
    end
  end

  describe "Event handling" do
    before do
      stub_const 'Foo', Class.new
      Foo.class_eval do
        include React::Component
      end
    end

    it "should work in render method" do
      Foo.class_eval do
        define_state(:clicked) { false }

        def render
          React.create_element("div").on(:click) do
            self.clicked = true
          end
        end
      end

      element = React.create_element(Foo)
      instance = renderElementToDocument(element)
      simulateEvent(:click, instance)
      expect(instance.state.clicked).to eq(true)
    end

    it "should invoke handler on `this.props` using emit" do
      Foo.class_eval do
        after_mount :setup

        def setup
          self.emit(:foo_submit, "bar")
        end

        def render
          React.create_element("div")
        end
      end

      expect { |b|
        element = React.create_element(Foo).on(:foo_submit, &b)
        renderElementToDocument(element)
      }.to yield_with_args("bar")
    end

    it "should invoke handler with multiple params using emit" do
      Foo.class_eval do
        after_mount :setup

        def setup
          self.emit(:foo_invoked, [1,2,3], "bar")
        end

        def render
          React.create_element("div")
        end
      end

      expect { |b|
        element = React.create_element(Foo).on(:foo_invoked, &b)
        renderElementToDocument(element)
      }.to yield_with_args([1,2,3], "bar")
    end
  end

  describe "Refs" do
    before do
      stub_const 'Foo', Class.new
      Foo.class_eval do
        include React::Component
      end
    end

    it "should correctly assign refs" do
      Foo.class_eval do
        def render
          React.create_element("input", type: :text, ref: :field)
        end
      end

      element = renderToDocument(Foo)
      expect(element.refs.field).not_to be_nil
    end

    it "should access refs through `refs` method" do
      Foo.class_eval do
        def render
          React.create_element("input", type: :text, ref: :field).on(:click) do
            refs[:field].value = "some_stuff"
          end
        end
      end

      element = renderToDocument(Foo)
      simulateEvent(:click, element)

      expect(element.refs.field.value).to eq("some_stuff")
    end
  end

  describe "Render" do
    it "should support element building helpers" do
      stub_const 'Foo', Class.new
      Foo.class_eval do
        include React::Component

        def render
          div do
            span { params[:foo] }
          end
        end
      end

      stub_const 'Bar', Class.new
      Bar.class_eval do
        include React::Component
        def render
          div do
            present Foo, foo: "astring"
          end
        end
      end

      expect(React.render_to_static_markup(React.create_element(Bar))).to eq("<div><div><span>astring</span></div></div>")
    end

    it "should build single node in top-level render without providing a block" do
      stub_const 'Foo', Class.new
      Foo.class_eval do
        include React::Component

        def render
          div
        end
      end

      element = React.create_element(Foo)
      expect(React.render_to_static_markup(element)).to eq("<div></div>")
    end
  end

  describe "isMounted()" do
    it "should return true if after mounted" do
      stub_const 'Foo', Class.new
      Foo.class_eval do
        include React::Component

        define_state(:mounted) { false }
        after_mount :verify

        def verify
          if self.mounted?
            self.mounted = true
          end
        end

        def render
          React.create_element("div")
        end
      end

      element = renderToDocument(Foo)
      expect(element.state.mounted).to eq(true)
    end
  end
end
