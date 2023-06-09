module Scheddy
  if defined?(ActiveRecord::Base)
    class ApplicationRecord < ActiveRecord::Base
      self.abstract_class = true
    end
  else
    class ApplicationRecord
    end
  end
end
