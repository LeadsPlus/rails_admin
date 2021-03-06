# coding: utf-8

require 'spec_helper'

describe "RailsAdmin Config DSL Edit Section" do

  subject { page }

  describe "default_value" do

    it "should be set for all types of input fields" do
      RailsAdmin.config do |config|
        config.excluded_models = []
        config.model(FieldTest) do

          field :string_field do
            default_value 'string_field default_value'
          end
          field :text_field do
            default_value 'string_field text_field'
          end
          field :boolean_field do
            default_value true
          end
          field :date_field do
            default_value Date.today.to_s
          end
        end
      end

      visit new_path(:model_name => "field_test")
      # In Rails 3.2.3 behavior of textarea has changed to insert newline after the opening tag,
      # but Capybara's RackTest driver is not up to this behavior change.
      # (https://github.com/jnicklas/capybara/issues/677)
      # So we manually cut off first newline character as a workaround here.
      find_field('field_test[string_field]').value.gsub(/^\n/, '').should == 'string_field default_value'
      find_field('field_test[text_field]').value.gsub(/^\n/, '').should == 'string_field text_field'
      find_field('field_test[date_field]').value.should == Date.today.to_s
      has_checked_field?('field_test[boolean_field]').should be_true
    end

    it "should set default value for selects" do
      RailsAdmin.config(Team) do
        field :color, :enum do
          default_value 'black'
          enum do
            ['black', 'white']
          end
        end
      end
      visit new_path(:model_name => "team")
      find_field('team[color]').value.should == 'black'
    end
  end

  describe "attr_accessible" do


    it "should be configurable in the controller scope" do

      RailsAdmin.config do |config|
        config.excluded_models = []
        config.attr_accessible_role do
          _current_user.attr_accessible_role # sould be :custom_role
        end

        config.model FieldTest do
          edit do
            field :string_field
            field :restricted_field
            field :protected_field
          end
        end
      end

      visit new_path(:model_name => "field_test")
      fill_in "field_test[string_field]", :with => "No problem here"
      fill_in "field_test[restricted_field]", :with => "I'm allowed to do that as :custom_role only"
      should have_no_selector "field_test[protected_field]"
      click_button "Save"
      @field_test = FieldTest.first
      @field_test.string_field.should == "No problem here"
      @field_test.restricted_field.should == "I'm allowed to do that as :custom_role only"
    end
  end

  describe "css hooks" do
    it "should be present" do
      visit new_path(:model_name => "team")
      should have_selector("#team_division_id_field.belongs_to_association_type.division_field")
    end
  end

  describe "field groupings" do

    it "should be hideable" do
      RailsAdmin.config Team do
        edit do
          group :default do
            label "Hidden group"
            hide
          end
        end
      end
      visit new_path(:model_name => "team")
      # Should not have the group header
      should have_no_selector("legend", :text => "Hidden Group")
      # Should not have any of the group's fields either
      should have_no_selector("select#team_division")
      should have_no_selector("input#team_name")
      should have_no_selector("input#team_logo_url")
      should have_no_selector("input#team_manager")
      should have_no_selector("input#team_ballpark")
      should have_no_selector("input#team_mascot")
      should have_no_selector("input#team_founded")
      should have_no_selector("input#team_wins")
      should have_no_selector("input#team_losses")
      should have_no_selector("input#team_win_percentage")
      should have_no_selector("input#team_revenue")
    end

    it "should hide association groupings" do
      RailsAdmin.config Team do
        edit do
          group :players do
            label "Players"
            field :players
            hide
          end
        end
      end
      visit new_path(:model_name => "team")
      # Should not have the group header
      should have_no_selector("legend", :text => "Players")
      # Should not have any of the group's fields either
      should have_no_selector("select#team_player_ids")
    end

    it "should be renameable" do
      RailsAdmin.config Team do
        edit do
          group :default do
            label "Renamed group"
          end
        end
      end
      visit new_path(:model_name => "team")
      should have_selector("legend", :text => "Renamed group")
    end

    describe "help" do
      before(:each) do
        class HelpTest < Tableless
          column :name, 'string(50)'
          column :division, :string
        end
        RailsAdmin.config.included_models = [HelpTest]
      end

      after(:each) do
        # restore validation setting
        HelpTest._validators[:name] = []
        HelpTest.reset_callbacks(:validate)
      end

      it "should show help section if present" do
        RailsAdmin.config HelpTest do
          edit do
            group :default do
              help "help paragraph to display"
            end
          end
        end
        visit new_path(:model_name => "help_test")
        should have_selector('fieldset>p', :text => "help paragraph to display")
      end

      it "should not show help if not present" do
        RailsAdmin.config HelpTest do
          edit do
            group :default do
              label 'no help'
            end
          end
        end
        visit new_path(:model_name => "help_test")
        should_not have_selector('fieldset>p')
      end

      it "should be able to display multiple help if there are multiple sections" do
        RailsAdmin.config HelpTest do
          edit do
            group :default do
              field :name
              help 'help for default'
            end
            group :other_section do
              label "Other Section"
              field :division
              help 'help for other section'
            end
          end
        end
        visit new_path(:model_name => "help_test")
        should have_selector("fieldset>p", :text => 'help for default')
        should have_selector("fieldset>p", :text => 'help for other section')
        should have_selector("fieldset>p", :count => 2)
      end

      it "should use the :is setting from the validation" do
        HelpTest.class_eval do
          validates_length_of :name, :is => 3
        end
        visit new_path(:model_name => "help_test")
        find("#help_test_name_field .help-block").should have_content("Length of 3.")
      end

      describe "using ORM column size", :skip_mongoid => true do
        it "should use the db column size for the maximum length" do
          visit new_path(:model_name => "help_test")
          find("#help_test_name_field .help-block").should have_content("Length up to 50.")
        end

        it "should use the :minimum setting from the validation" do
          HelpTest.class_eval do
            validates_length_of :name, :minimum => 1
          end
          visit new_path(:model_name => "help_test")
          find("#help_test_name_field .help-block").should have_content("Length of 1-50.")
        end

        it "should use the :maximum setting from the validation" do
          HelpTest.class_eval do
            validates_length_of :name, :maximum => 49
          end
          visit new_path(:model_name => "help_test")
          find("#help_test_name_field .help-block").should have_content("Length up to 49.")
        end

        it "should use the minimum of db column size or :maximum setting from the validation" do
          HelpTest.class_eval do
            validates_length_of :name, :maximum => 51
          end
          visit new_path(:model_name => "help_test")
          find("#help_test_name_field .help-block").should have_content("Length up to 50.")
        end
      end

      it "should use the :minimum and :maximum from the validation" do
        HelpTest.class_eval do
          validates_length_of :name, :minimum => 1, :maximum => 49
        end
        visit new_path(:model_name => "help_test")
        find("#help_test_name_field .help-block").should have_content("Length of 1-49.")
      end

      it "should use the range from the validation" do
        HelpTest.class_eval do
          validates_length_of :name, :in => 1..49
        end
        visit new_path(:model_name => "help_test")
        find("#help_test_name_field .help-block").should have_content("Length of 1-49.")
      end

    end

    it "should have accessor for its fields" do
      RailsAdmin.config Team do
        edit do
          group :default do
            field :name
            field :logo_url
          end
          group :belongs_to_associations do
            label "Belong's to associations"
            field :division
          end
          group :basic_info do
            field :manager
          end
        end
      end
      visit new_path(:model_name => "team")
      should have_selector("legend", :text => "Basic info")
      all("legend", :text => "Basic info").tap do |nodes|
        nodes.count.should == 2
        nodes.first.visible?.should be_false
        nodes.last.visible?.should be_true
      end
      should have_selector("legend", :text => "Belong's to associations")
      should have_selector("label", :text => "Name")
      should have_selector("label", :text => "Logo url")
      should have_selector("label", :text => "Division")
      should have_selector(".control-group", :count => 4)
    end

    it "should have accessor for its fields by type" do
      RailsAdmin.config Team do
        edit do
          group :default do
            field :name
            field :logo_url
          end
          group :other do
            field :division_id
            field :manager
            field :ballpark
            fields_of_type :string do
              label { "#{label} (STRING)" }
            end
          end
        end
      end
      visit new_path(:model_name => "team")
      should have_selector("label", :text => "Name")
      should have_selector("label", :text => "Logo url")
      should have_selector("label", :text => "Division")
      should have_selector("label", :text => "Manager (STRING)")
      should have_selector("label", :text => "Ballpark (STRING)")
    end
  end

  describe "items' fields" do

    it "should show all by default" do
      visit new_path(:model_name => "team")
      should have_selector("select#team_division_id")
      should have_selector("input#team_name")
      should have_selector("input#team_logo_url")
      should have_selector("input#team_manager")
      should have_selector("input#team_ballpark")
      should have_selector("input#team_mascot")
      should have_selector("input#team_founded")
      should have_selector("input#team_wins")
      should have_selector("input#team_losses")
      should have_selector("input#team_win_percentage")
      should have_selector("input#team_revenue")
      should have_selector("select#team_player_ids")
      should have_selector("select#team_fan_ids")
    end

    it "should appear in order defined" do
      RailsAdmin.config Team do
        edit do
          field :manager
          field :division
          field :name
        end
      end
      visit new_path(:model_name => "team")
      should have_selector(:xpath, "//*[contains(@class, 'field')][1]//*[@id='team_manager']")
      should have_selector(:xpath, "//*[contains(@class, 'field')][2]//*[@id='team_division_id']")
      should have_selector(:xpath, "//*[contains(@class, 'field')][3]//*[@id='team_name']")
    end

    it "should only show the defined fields if some fields are defined" do
      RailsAdmin.config Team do
        edit do
          field :division
          field :name
        end
      end
      visit new_path(:model_name => "team")
      should have_selector("label", :text => "Division")
      should have_selector("label", :text => "Name")
      should have_selector(".control-group", :count => 2)
    end

    it "should delegates the label option to the ActiveModel API and memoize I18n awarly" do
      RailsAdmin.config Team do
        edit do
          field :manager
          field :fans
        end
      end
      visit new_path(:model_name => "team")
      should have_selector("label", :text => "Team Manager")
      should have_selector("label", :text => "Some Fans")
      I18n.locale = :fr
      visit new_path(:model_name => "team")
      should have_selector("label", :text => "Manager de l'équipe")
      should have_selector("label", :text => "Quelques fans")
      I18n.locale = :en
    end

    it "should be renameable" do
      RailsAdmin.config Team do
        edit do
          field :manager do
            label "Renamed field"
          end
          field :division
          field :name
        end
      end
      visit new_path(:model_name => "team")
      should have_selector("label", :text => "Renamed field")
      should have_selector("label", :text => "Division")
      should have_selector("label", :text => "Name")
    end

    it "should be renameable by type" do
      RailsAdmin.config Team do
        edit do
          fields_of_type :string do
            label { "#{label} (STRING)" }
          end
        end
      end
      visit new_path(:model_name => "team")
      should have_selector("label", :text => "Division")
      should have_selector("label", :text => "Name (STRING)")
      should have_selector("label", :text => "Logo url (STRING)")
      should have_selector("label", :text => "Manager (STRING)")
      should have_selector("label", :text => "Ballpark (STRING)")
      should have_selector("label", :text => "Mascot (STRING)")
      should have_selector("label", :text => "Founded")
      should have_selector("label", :text => "Wins")
      should have_selector("label", :text => "Losses")
      should have_selector("label", :text => "Win percentage")
      should have_selector("label", :text => "Revenue")
      should have_selector("label", :text => "Players")
      should have_selector("label", :text => "Fans")
    end

    it "should be globally renameable by type" do
      RailsAdmin::Config.models do
        edit do
          fields_of_type :string do
            label { "#{label} (STRING)" }
          end
        end
      end
      visit new_path(:model_name => "team")
      should have_selector("label", :text => "Division")
      should have_selector("label", :text => "Name (STRING)")
      should have_selector("label", :text => "Logo url (STRING)")
      should have_selector("label", :text => "Manager (STRING)")
      should have_selector("label", :text => "Ballpark (STRING)")
      should have_selector("label", :text => "Mascot (STRING)")
      should have_selector("label", :text => "Founded")
      should have_selector("label", :text => "Wins")
      should have_selector("label", :text => "Losses")
      should have_selector("label", :text => "Win percentage")
      should have_selector("label", :text => "Revenue")
      should have_selector("label", :text => "Players")
      should have_selector("label", :text => "Fans")
    end

    it "should be flaggable as read only and be configurable with formatted_value" do
      RailsAdmin.config Team do
        edit do
          field :name do
            read_only true
            formatted_value do
              "I'm outputed in the form"
            end
          end
        end
      end
      visit new_path(:model_name => "team")
      should have_content("I'm outputed in the form")
    end

    it "should be hideable" do
      RailsAdmin.config Team do
        edit do
          field :manager do
            hide
          end
          field :division
          field :name
        end
      end
      visit new_path(:model_name => "team")
      should have_no_selector("#team_manager")
      should have_selector("#team_division_id")
      should have_selector("#team_name")
    end

    it "should be hideable by type" do
      RailsAdmin.config Team do
        edit do
          fields_of_type :string do
            hide
          end
        end
      end
      visit new_path(:model_name => "team")
      should have_selector("label", :text => "Division")
      should have_no_selector("label", :text => "Name")
      should have_no_selector("label", :text => "Logo url")
      should have_no_selector("label", :text => "Manager")
      should have_no_selector("label", :text => "Ballpark")
      should have_no_selector("label", :text => "Mascot")
      should have_selector("label", :text => "Founded")
      should have_selector("label", :text => "Wins")
      should have_selector("label", :text => "Losses")
      should have_selector("label", :text => "Win percentage")
      should have_selector("label", :text => "Revenue")
      should have_selector("label", :text => "Players")
      should have_selector("label", :text => "Fans")
    end

    it "should be globally hideable by type" do
      RailsAdmin::Config.models do
        edit do
          fields_of_type :string do
            hide
          end
        end
      end
      visit new_path(:model_name => "team")
      should have_selector("label", :text => "Division")
      should have_no_selector("label", :text => "Name")
      should have_no_selector("label", :text => "Logo url")
      should have_no_selector("label", :text => "Manager")
      should have_no_selector("label", :text => "Ballpark")
      should have_no_selector("label", :text => "Mascot")
      should have_selector("label", :text => "Founded")
      should have_selector("label", :text => "Wins")
      should have_selector("label", :text => "Losses")
      should have_selector("label", :text => "Win percentage")
      should have_selector("label", :text => "Revenue")
      should have_selector("label", :text => "Players")
      should have_selector("label", :text => "Fans")
    end

    it "should have option to customize the help text" do
      RailsAdmin.config Team do
        edit do
          field :manager do
            help "#{help} Additional help text for manager field."
          end
          field :division
          field :name
        end
      end
      visit new_path(:model_name => "team")
      find("#team_manager_field .help-block").should have_content("Required. Length up to 100. Additional help text for manager field.")
      find("#team_division_id_field .help-block").should have_content("Required")
      find("#team_name_field .help-block").should_not have_content("Additional help text")
    end

    it "should have option to override required status" do
      RailsAdmin.config Team do
        edit do
          field :manager do
            optional true
          end
          field :division do
            optional true
          end
          field :name do
            required true
          end
        end
      end
      visit new_path(:model_name => "team")
      find("#team_manager_field .help-block").should have_content("Optional")
      find("#team_division_id_field .help-block").should have_content("Optional")
      find("#team_name_field .help-block").should have_content("Required")
    end
  end

  describe "input format of" do

    before(:each) do
      @time = ::Time.now.getutc
    end

    after(:each) do
      Time.zone = 'UTC'
    end

    describe "a datetime field" do

      it "should default to %B %d, %Y %H:%M" do
        visit new_path(:model_name => "field_test")
        fill_in "field_test[datetime_field]", :with => @time.strftime("%B %d, %Y %H:%M")
        click_button "Save"
        @record = RailsAdmin::AbstractModel.new("FieldTest").first
        @record.datetime_field.strftime("%Y-%m-%d %H:%M").should eql(@time.strftime("%Y-%m-%d %H:%M"))
      end

      it "should have a simple customization option" do
        RailsAdmin.config FieldTest do
          edit do
            field :datetime_field do
              date_format :default
            end
          end
        end
        visit new_path(:model_name => "field_test")
        fill_in "field_test[datetime_field]", :with => @time.strftime("%a, %d %b %Y %H:%M:%S")
        click_button "Save"
        @record = RailsAdmin::AbstractModel.new("FieldTest").first
        @record.datetime_field.to_s(:rfc822).should eql(@time.to_s(:rfc822))
      end

      it "should have a customization option" do
        RailsAdmin.config FieldTest do
          list do
            field :datetime_field do
              strftime_format "%Y-%m-%d %H:%M:%S"
            end
          end
        end
        visit new_path(:model_name => "field_test")
        fill_in "field_test[datetime_field]", :with => @time.strftime("%Y-%m-%d %H:%M:%S")
        click_button "Save"
        @record = RailsAdmin::AbstractModel.new("FieldTest").first
        @record.datetime_field.to_s(:rfc822).should eql(@time.to_s(:rfc822))
      end
    end

    describe "a timestamp field", :active_record => true do

      it "should default to %B %d, %Y %H:%M" do
        visit new_path(:model_name => "field_test")
        fill_in "field_test[timestamp_field]", :with => @time.strftime("%B %d, %Y %H:%M")
        click_button "Save"
        @record = RailsAdmin::AbstractModel.new("FieldTest").first
        @record.timestamp_field.strftime("%Y-%m-%d %H:%M").should eql(@time.strftime("%Y-%m-%d %H:%M"))
      end

      it "should have a simple customization option" do
        RailsAdmin.config FieldTest do
          edit do
            field :timestamp_field do
              date_format :default
            end
          end
        end
        visit new_path(:model_name => "field_test")
        fill_in "field_test[timestamp_field]", :with => @time.strftime("%a, %d %b %Y %H:%M:%S")
        click_button "Save"
        @record = RailsAdmin::AbstractModel.new("FieldTest").first
        @record.timestamp_field.to_s(:rfc822).should eql(@time.to_s(:rfc822))
      end

      it "should have a customization option" do
        RailsAdmin.config FieldTest do
          edit do
            field :timestamp_field do
              strftime_format "%Y-%m-%d %H:%M:%S"
            end
          end
        end
        visit new_path(:model_name => "field_test")
        fill_in "field_test[timestamp_field]", :with => @time.strftime("%Y-%m-%d %H:%M:%S")
        click_button "Save"
        @record = RailsAdmin::AbstractModel.new("FieldTest").first
        @record.timestamp_field.to_s(:rfc822).should eql(@time.to_s(:rfc822))
      end
    end

    describe " a field with 'format' as a name (Kernel function)" do

      it "should be updatable without any error" do
        RailsAdmin.config FieldTest do
          edit do
            field :format
          end
        end
        visit new_path(:model_name => "field_test")
        fill_in "field_test[format]", :with => "test for format"
        click_button "Save"
        @record = RailsAdmin::AbstractModel.new("FieldTest").first
        @record.format.should eql("test for format")
      end
    end


    describe "a time field" do

      it "should default to %H:%M" do
        visit new_path(:model_name => "field_test")
        fill_in "field_test[time_field]", :with => @time.strftime("%H:%M")
        click_button "Save"
        @record = RailsAdmin::AbstractModel.new("FieldTest").first
        @record.time_field.strftime("%H:%M").should eql(@time.strftime("%H:%M"))
      end

      it "should interpret time value as UTC when timezone is specified" do
        Time.zone = 'Eastern Time (US & Canada)' # -05:00

        visit new_path(:model_name => "field_test")
        fill_in "field_test[time_field]", :with => @time.strftime("%H:%M")
        click_button "Save"
        @record = RailsAdmin::AbstractModel.new("FieldTest").first
        @record.time_field.strftime("%H:%M").should eql(@time.strftime("%H:%M"))
      end

      it "should have a customization option" do
        RailsAdmin.config FieldTest do
          edit do
            field :time_field do
              strftime_format "%I:%M %p"
            end
          end
        end
        visit new_path(:model_name => "field_test")
        fill_in "field_test[time_field]", :with => @time.strftime("%I:%M %p")
        click_button "Save"
        @record = RailsAdmin::AbstractModel.new("FieldTest").first
        @record.time_field.strftime("%H:%M").should eql(@time.strftime("%H:%M"))
      end
    end

    describe "a date field" do

      it "should default to %B %d, %Y" do
        visit new_path(:model_name => "field_test")
        fill_in "field_test[date_field]", :with => @time.strftime("%B %d, %Y")
        click_button "Save"
        @record = RailsAdmin::AbstractModel.new("FieldTest").first
        @record.date_field.should eql(::Date.parse(@time.to_s))
      end

      it "should cover a timezone lag even if in UTC+n:00 timezone." do
        Time.zone = 'Tokyo' # +09:00

        visit new_path(:model_name => "field_test")
        fill_in "field_test[date_field]", :with => @time.strftime("%B %d, %Y")
        click_button "Save"
        @record = RailsAdmin::AbstractModel.new("FieldTest").first
        @record.date_field.should eql(::Date.parse(@time.to_s))
      end

      it "should have a simple customization option" do
        RailsAdmin.config FieldTest do
          edit do
            field :date_field do
              date_format :default
            end
          end
        end
        visit new_path(:model_name => "field_test")
        fill_in "field_test[date_field]", :with => @time.strftime("%Y-%m-%d")
        click_button "Save"
        @record = RailsAdmin::AbstractModel.new("FieldTest").first
        @record.date_field.should eql(::Date.parse(@time.to_s))
      end

      it "should have a customization option" do
        RailsAdmin.config FieldTest do
          edit do
            field :date_field do
              strftime_format "%Y-%m-%d"
            end
          end
        end
        visit new_path(:model_name => "field_test")
        fill_in "field_test[date_field]", :with => @time.strftime("%Y-%m-%d")
        click_button "Save"
        @record = RailsAdmin::AbstractModel.new("FieldTest").first
        @record.date_field.should eql(::Date.parse(@time.to_s))
      end
    end
  end

  describe 'bindings' do
    it 'should be present at creation time' do
      RailsAdmin.config do |config|
        config.excluded_models = []
      end
      RailsAdmin.config Category do
        field :parent_category do
          visible do
            !bindings[:object].new_record?
          end
        end
      end

      visit new_path(:model_name => 'category')
      should have_no_css('#category_parent_category_id')
      click_button 'Save'
      visit edit_path(:model_name => 'category', :id => Category.first)
      should have_css('#category_parent_category_id')
      click_button 'Save'
      should have_content('Category successfully updated')
    end
  end

  describe 'nested form' do
    it 'should work' do
      visit new_path(:model_name => "field_test")
      fill_in "field_test_comment_attributes_content", :with => 'nested comment content'
      click_button "Save"
      @record = RailsAdmin::AbstractModel.new("FieldTest").first
      @record.comment.content.should == 'nested comment content'
      @record.nested_field_tests = [NestedFieldTest.create!(:title => 'title 1'), NestedFieldTest.create!(:title => 'title 2')]
      visit edit_path(:model_name => "field_test", :id => @record.id)
      fill_in "field_test_nested_field_tests_attributes_0_title", :with => 'nested field test title 1 edited'
      page.find('#field_test_nested_field_tests_attributes_1__destroy').set('true')
      click_button "Save"
      @record.reload
      @record.nested_field_tests.length.should == 1
      @record.nested_field_tests[0].title.should == 'nested field test title 1 edited'
    end

    it 'should set bindings[:object] to nested object' do
      RailsAdmin.config(NestedFieldTest) do
        nested do
          field :title do
            label do
              bindings[:object].class.name
            end
          end
        end
      end
      @record = FieldTest.create
      @record.nested_field_tests << NestedFieldTest.create!(:title => 'title 1')
      visit edit_path(:model_name => "field_test", :id => @record.id)
      find('#field_test_nested_field_tests_attributes_0_title_field').should have_content('NestedFieldTest')
    end

    it 'should be desactivable' do
      visit new_path(:model_name => "field_test")
      should have_selector('#field_test_nested_field_tests_attributes_field .add_nested_fields')
      RailsAdmin.config(FieldTest) do
        configure :nested_field_tests do
          nested_form false
        end
      end
      visit new_path(:model_name => "field_test")
      should have_no_selector('#field_test_nested_field_tests_attributes_field .add_nested_fields')
    end

    describe "with nested_attributes_options given" do
      before do
        FieldTest.nested_attributes_options.stub(:[]).with(any_args()).
          and_return({:allow_destroy=>true, :update_only=>false})
      end

      it 'should not show add button when :update_only is true' do
        FieldTest.nested_attributes_options.stub(:[]).with(:nested_field_tests).
          and_return({:allow_destroy=>true, :update_only=>true})
        visit new_path(:model_name => "field_test")
        should have_selector('.toggler')
        should_not have_selector('#field_test_nested_field_tests_attributes_field .add_nested_fields')
      end

      it 'should not show destroy button except for newly created when :allow_destroy is false' do
        @record = FieldTest.create
        @record.nested_field_tests << NestedFieldTest.create!(:title => 'nested title 1')
        FieldTest.nested_attributes_options.stub(:[]).with(:nested_field_tests).
          and_return({:allow_destroy=>false, :update_only=>false})
        visit edit_path(:model_name => "field_test", :id => @record.id)
        find('#field_test_nested_field_tests_attributes_0_title').value.should == 'nested title 1'
        should_not have_selector('form .remove_nested_fields')
        should have_selector('.fields_blueprint .remove_nested_fields')
      end
    end

    describe "when a field which have the same name of nested_in field's" do
      it "should not hide fields which is not associated with nesting parent field's model" do
        visit new_path(:model_name => "field_test")
        should_not have_selector('select#field_test_nested_field_tests_attributes_new_nested_field_tests_field_test_id')
        should have_selector('select#field_test_nested_field_tests_attributes_new_nested_field_tests_another_field_test_id')
      end
    end
  end

  describe 'embedded model', :mongoid => true do
    it 'should work' do
      @record = FactoryGirl.create :field_test
      2.times.each{|i| @record.embeds.create :name => "embed #{i}"}
      visit edit_path(:model_name => "field_test", :id => @record.id)
      fill_in "field_test_embeds_attributes_0_name", :with => 'embed 1 edited'
      page.find('#field_test_embeds_attributes_1__destroy').set('true')
      click_button "Save"
      @record.reload
      @record.embeds.length.should == 1
      @record.embeds[0].name.should == 'embed 1 edited'
    end
  end


  describe "fields which are nullable and have AR validations", :active_record => true do

    it "should be required" do
      # draft.notes is nullable and has no validation
      field = RailsAdmin::config("Draft").edit.fields.find{|f| f.name == :notes}
      field.properties[:nullable?].should be true
      field.required?.should be false

      # draft.date is nullable in the schema but has an AR
      # validates_presence_of validation that makes it required
      field = RailsAdmin::config("Draft").edit.fields.find{|f| f.name == :date}
      field.properties[:nullable?].should be true
      field.required?.should be true

      # draft.round is nullable in the schema but has an AR
      # validates_numericality_of validation that makes it required
      field = RailsAdmin::config("Draft").edit.fields.find{|f| f.name == :round}
      field.properties[:nullable?].should be true
      field.required?.should be true

      # team.revenue is nullable in the schema but has an AR
      # validates_numericality_of validation that allows nil
      field = RailsAdmin::config("Team").edit.fields.find{|f| f.name == :revenue}
      field.properties[:nullable?].should be true
      field.required?.should be false
    end
  end

  describe "CKEditor Support" do

    it "should start with CKEditor disabled" do
       field = RailsAdmin::config("Draft").edit.fields.find{|f| f.name == :notes}
       field.ckeditor.should be false
    end

    it "should add Javascript to enable CKEditor" do
      RailsAdmin.config Draft do
        edit do
          field :notes do
            ckeditor true
          end
        end
      end
      visit new_path(:model_name => "draft")
      should have_selector('textarea#draft_notes[data-richtext="ckeditor"]')
    end
  end

  describe "CodeMirror Support" do

    it "should start with CodeMirror disabled" do
       field = RailsAdmin::config("Draft").edit.fields.find{|f| f.name == :notes}
       field.codemirror.should be false
    end

    it "should add Javascript to enable CodeMirror" do
      RailsAdmin.config Draft do
        edit do
          field :notes do
            codemirror true
          end
        end
      end
      visit new_path(:model_name => "draft")
      should have_selector('textarea#draft_notes[data-richtext="codemirror"]')
    end
  end

  describe "Paperclip Support" do

    it "should show a file upload field" do
      RailsAdmin.config User do
        edit do
          field :avatar
        end
      end
      visit new_path(:model_name => "user")
      should have_selector("input#user_avatar")
    end
  end

  describe "Enum field support" do
    describe "when object responds to '\#{method}_enum'" do
      before do
        Team.class_eval do
          def color_enum
            ["blue", "green", "red"]
          end
        end
        RailsAdmin.config Team do
          edit do
            field :color
          end
        end
        visit new_path(:model_name => "team")
      end

      after do
        Team.send(:remove_method, :color_enum)
      end

      it "should auto-detect enumeration" do
        should have_selector(".enum_type select")
        should_not have_selector(".enum_type select[multiple]")
        should have_content("green")
      end
    end

    describe "when class responds to '\#{method}_enum'" do
      before do
        Team.instance_eval do
          def color_enum
            ["blue", "green", "red"]
          end
        end
        RailsAdmin.config Team do
          edit do
            field :color
          end
        end
        visit new_path(:model_name => "team")
      end

      after do
        Team.instance_eval { undef :color_enum }
      end

      it "should auto-detect enumeration" do
        should have_selector(".enum_type select")
        should have_content("green")
      end
    end

    describe "the enum instance method" do
      before do
        Team.class_eval do
          def color_list
            ["blue", "green", "red"]
          end
        end
        RailsAdmin.config Team do
          edit do
            field :color, :enum do
              enum_method :color_list
            end
          end
        end
        visit new_path(:model_name => "team")
      end

      after do
        Team.send(:remove_method, :color_list)
      end

      it "should allow configuration" do
        should have_selector(".enum_type select")
        should have_content("green")
      end
    end

    describe "the enum class method" do
      before do
        Team.instance_eval do
          def color_list
            ["blue", "green", "red"]
          end
        end
        RailsAdmin.config Team do
          edit do
            field :color, :enum do
              enum_method :color_list
            end
          end
        end
        visit new_path(:model_name => "team")
      end

      after do
        Team.instance_eval { undef :color_list }
      end

      it "should allow configuration" do
        should have_selector(".enum_type select")
        should have_content("green")
      end
    end

    describe "when overriding enum configuration" do
      before do
        Team.class_eval do
          def color_list
            ["blue", "green", "red"]
          end
        end
        RailsAdmin.config Team do
          edit do
            field :color, :enum do
              enum_method :color_list
              enum do
                ["yellow", "black"]
              end
            end
          end
        end
        visit new_path(:model_name => "team")
      end

      after do
        Team.send(:remove_method, :color_list)
      end

      it "should allow direct listing of enumeration options and override enum method" do
        should have_selector(".enum_type select")
        should have_no_content("green")
        should have_content("yellow")
      end
    end

    describe "when serialize is enabled in ActiveRecord model", :active_record => true do
      before do
        Team.instance_eval do
          serialize :color
          def color_enum
            ["blue", "green", "red"]
          end
        end
        visit new_path(:model_name => "team")
      end

      after do
        Team.serialized_attributes.clear
        Team.instance_eval { undef :color_enum }
      end

      it "should make enumeration multi-selectable" do
        should have_selector(".enum_type select[multiple]")
      end
    end

    describe "when serialize is enabled in Mongoid model", :mongoid => true do
      before do
        Team.instance_eval do
          field :color, :type => Array
          def color_enum
            ["blue", "green", "red"]
          end
        end
        visit new_path(:model_name => "team")
      end

      after do
        Team.instance_eval do
          field :color, :type => String
          undef :color_enum
        end
      end

      it "should make enumeration multi-selectable" do
        should have_selector(".enum_type select[multiple]")
      end
    end
  end

  describe "ColorPicker Support" do
    it "should show input with class color" do
      RailsAdmin.config Team do
        edit do
          field :color, :color
        end
      end
      visit new_path(:model_name => "team")
      should have_selector(".color_type input")
    end
  end
end
