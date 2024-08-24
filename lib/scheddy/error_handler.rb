module Scheddy
  # called from within task's execution thread; must be multi-thread safe
  # task is allowed to be nil
  mattr_accessor :error_handler, default: lambda {|e, task|
    task &&= "task '#{task&.name}' "
    logger.error "Exception in Scheddy #{task}: #{e.inspect}\n  #{e.backtrace.join("\n  ")}"
    Rails.error.report(e, handled: true, severity: :error)
  }

  def self.handle_error(e, task=nil)
    if h = Scheddy.error_handler
      h.call(*[e, task].take(h.arity.abs))
    end
  end

end
