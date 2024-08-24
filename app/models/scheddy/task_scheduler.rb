module Scheddy
  class TaskScheduler < ApplicationRecord

    validates :leader_expires_at,
      presence: {if: :leader_state},
      absence: {unless: :leader_state}

    validates :leader_state,
      inclusion: [nil, 'leader']


    scope :leader,     ->{ where(leader_state: 'leader') }
    scope :not_leader, ->{ where.not(leader_state: 'leader') }
    scope :stale,      ->{ where(last_seen_at: ..2.hours.ago).not_leader }


    def expired?
      leader_expires_at && leader_expires_at < Time.current
    end

    def leader?
      leader_state == 'leader'
    end


    def clear_leader(only_if_expired: false)
      reload if changed?
      with_lock do
        if !only_if_expired || expired?
          update! leader_state: nil, leader_expires_at: nil
        end
      end
    end

    def mark_seen
      if last_seen_at < (LEASE_RENEWAL_INTERVAL - 5.seconds).ago
        update! last_seen_at: Time.current
      end
    end

    def renew_leadership
      if last_seen_at < (LEASE_RENEWAL_INTERVAL - 5.seconds).ago
        update! leader_expires_at: LEASE_DURATION.from_now, last_seen_at: Time.current
      else
        true
      end
    rescue ActiveRecord::StaleObjectError
      reload
      false
    end

    def take_leadership
      update! leader_state: 'leader', leader_expires_at: LEASE_DURATION.from_now, last_seen_at: Time.current
    rescue ActiveRecord::RecordNotUnique
      false
    end

    def request_stepdown
      # intentionally leaves self.lock_version behind
      self.class.increment_counter :lock_version, id, touch: true if leader?
    end

  end
end
