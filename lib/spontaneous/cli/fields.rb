
module Spontaneous
  module Cli
    class Fields < ::Thor
      include Spontaneous::Cli::TaskUtils
      include ::Simultaneous::Task

      namespace :fields

      desc "update", "Performs asynchronous updates on provided fields"
      method_option :fields, :type => :array, :desc => "List of field IDs to update"
      def update
        prepare! :update, :console
        fields = Spontaneous::Field.find(*options.fields)
        updater = Spontaneous::Field::Update::Immediate.new(fields)
        unlocked_pages = updater.pages.reject { |p| p.locked_for_update? }
        updater.run
        send_completion_event(updater)
      end

      private

      def send_completion_event(updater)
        unlocked_pages = updater.pages.reject { |p| p.locked_for_update? }
        simultaneous_event('page_lock_status', unlocked_pages.map(&:id).to_json)
      end
    end
  end
end

