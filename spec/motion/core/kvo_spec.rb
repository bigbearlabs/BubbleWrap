describe BubbleWrap::KVO do

  class KvoExample
    include BubbleWrap::KVO

    attr_accessor :age
    attr_accessor :label
    attr_accessor :items

    def initialize
      @items = [ "Apple", "Banana", "Chickpeas" ]
      @age = 1

      if App.osx?
        @label = NSTextField.alloc.initWithFrame [[0,0],[320, 30]]
        @label.stringValue = "Foo"
      else
        @label = UILabel.alloc.initWithFrame [[0,0],[320, 30]]
        @label.text = "Foo"
      end
    end

    # Test helper

    def get_text
      App.osx? ? @label.stringValue : @label.text
    end

    def set_text(text)
      method = App.osx? ? :stringValue : :text
      @label.send("#{method}=", text)
    end

    def observe_label(&block)
      method = App.osx? ? :stringValue : :text
      observe(@label, method, &block)
    end

    def observe_collection(&block)
      observe(self, :items, &block)
    end

    def unobserve_label
      method = App.osx? ? :stringValue : :text
      unobserve(@label, method)
    end

    #  def unobserve_all
    #unobserve(@label, "text")
    #unobserve(self, "items")
    #end

  end

  describe "Callbacks" do
    before do
      @example = KvoExample.new
    end

    after do
      @example = nil
    end

    # add

    it "should add an observer block" do
      target = Object.new
      block = lambda { |old_value, new_value| }
      @example.send(:add_observer_block, target, "key_path", &block)
      @example.send(:registered?, target, "key_path").should == true
    end

    it "should not add an observer block if the key path is not present" do
      target = Object.new
      block = lambda { |old_value, new_value| }
      @example.send(:add_observer_block, target, nil, &block)
      @example.send(:registered?, target, nil).should == false
    end

    it "should not add an observer block if the block is not present" do
      target = Object.new
      @example.send(:add_observer_block, target, "key_path")
      @example.send(:registered?, target, "key_path").should == false
    end

    # remove

    it "should remove an observer block" do
      target = Object.new
      block = lambda { |old_value, new_value| }
      @example.send(:add_observer_block, target, "key_path", &block)
      @example.send(:remove_observer_block, target, "key_path")
      @example.send(:registered?, target, "key_path").should == false
    end

    it "should not remove an observer block if the target is not present" do
      target = Object.new
      block = lambda { |old_value, new_value| }
      @example.send(:add_observer_block, target, "key_path", &block)
      @example.send(:remove_observer_block, nil, "key_path")
      @example.send(:registered?, target, "key_path").should == true
    end
  
    it "should not remove an observer block if the key path is not present" do
      target = Object.new
      block = lambda { |old_value, new_value| }
      @example.send(:add_observer_block, target, "key_path", &block)
      @example.send(:remove_observer_block, target, nil)
      @example.send(:registered?, target, "key_path").should == true
    end
  
    it "should remove only one observer block" do
      target = Object.new
      block = lambda { |old_value, new_value| }
      @example.send(:add_observer_block, target, "key_path1", &block)
      @example.send(:add_observer_block, target, "key_path2", &block)
      @example.send(:remove_observer_block, target, "key_path1")
      @example.send(:registered?, target, "key_path1").should == false
      @example.send(:registered?, target, "key_path2").should == true
    end
  
    # remove all
  
    it "should remove all observer blocks" do
      target = Object.new
      block = lambda { |old_value, new_value| }
      @example.send(:add_observer_block, target, "key_path1", &block)
      @example.send(:add_observer_block, target, "key_path2", &block)
      @example.send(:remove_all_observer_blocks)
      @example.send(:registered?, target, "key_path1").should == false
      @example.send(:registered?, target, "key_path2").should == false    
    end
    
  end
  
  describe "API" do
    before do
      @example = KvoExample.new
    end
  
    after do
      @example.unobserve_all
      @example = nil
    end
    
    # observe

    it "should observe a key path" do
      observed = false
      @example.observe_label do |old_value, new_value|
        observed = true
        old_value.should == "Foo"
        new_value.should == "Bar"
      end
    
      @example.set_text "Bar"
      observed.should == true
    end
  
    it "should observe a key path with more than one block" do
      observed_one = false
      observed_two = false
      observed_three = false
      @example.observe_label do |old_value, new_value|
        observed_one = true
      end
      @example.observe_label do |old_value, new_value|
        observed_two = true
      end
      @example.observe_label do |old_value, new_value|
        observed_three = true
      end
    
      @example.set_text "Bar"
      observed_one.should == true
      observed_two.should == true
      observed_three.should == true
    end
    
    # unobserve
    
    it "should unobserve a key path" do
      observed = false
      @example.observe_label do |old_value, new_value|
        observed = true
      end
      @example.unobserve_label
    
      @example.set_text "Bar"
      observed.should == false
    end

    # without target

    it "should observe a key path without a target" do
      observed = false
      @example.observe :age do |old_value, new_value|
        observed = true
        old_value.should == 1
        new_value.should == 2
      end
    
      @example.age = 2
      observed.should == true
    end

    it "should unobserve a key path without a target" do
      observed = false
      @example.observe :age do |old_value, new_value|
        observed = true
      end
      @example.unobserve :age
    
      @example.age = 2
      observed.should == false
    end
  
    #

    it "should observe a key path with many segments" do
      observed = false
      @example.observe 'label.text' do |old_value, new_value|
        observed = true
      end

      @example.label.text = 'some val'      
      observed.should == true
    end

    it "should be orthogonal to eigenclass modifications" do
      # set an ivar
      class << @example
        def init_ivar
          @ivar = "I'm an ivar."
        end
      end

      observed1 = false
      observed2 = false
      @example.observe :age do |old_value, new_value|
        observed1 = true
      end
      @example.observe 'label.text' do |old_value, new_value|
        observed2 = true
      end

      @example.init_ivar
      @example.age = 42
      @example.label.text = 'some val'

      puts "class hierarchy: #{@example.class.ancestors}"
      puts "ivars: #{@example.instance_variables}"

      observed1.should == true
      observed2.should == true
      @example.age.should == 42
      @example.instance_variable_get(:@age).should == 42
      @example.instance_variable_get(:@ivar).should == "I'm an ivar."
    end

    # TODO should allow observations for same key registered from different subclasses

    # TODO should be orthogonal to mixins

    # TODO should work with property supplied by module



  end

=begin
  it "should be able to observe a collection" do
    observed = false
    @example.observe_collection do |old_value, new_value, indexes|
      puts "#{collection} #{old_value} #{new_value} #{indexes}"
      observed = true
    end
    
    @example.items << "Dragonfruit"
    observed.should == true  
  end
=end

end
