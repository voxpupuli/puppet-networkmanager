# frozen_string_literal: true

require 'facter'
require 'shellwords'

module PuppetX
  module Networkmanager
    module Facts
      module AllConnections
        module_function

        def fetch_connection_details(connection)
          output = Facter::Core::Execution.execute("nmcli -t connection show #{Shellwords.escape(connection)}")
          data = output.each_line.map(&:strip).reject(&:empty?).to_h do |item|
            item.split(':', 2).map { |value| value.strip.empty? ? nil : value.strip }
          end

          details = {}

          ipv4 = {
            'method' => data['ipv4.method'],
            'address' => split_profile_list(data['ipv4.addresses']),
            'dns' => split_profile_list(data['ipv4.dns']),
            'gateway' => data['ipv4.gateway'],
          }.compact
          details['ipv4'] = ipv4 unless ipv4.empty?

          ipv6 = {
            'method' => data['ipv6.method'],
            'address' => split_profile_list(data['ipv6.addresses']),
            'dns' => split_profile_list(data['ipv6.dns']),
            'gateway' => data['ipv6.gateway'],
          }.compact
          details['ipv6'] = ipv6 unless ipv6.empty?

          details.empty? ? nil : details
        rescue StandardError
          nil
        end

        # This intentionally mirrors the provider helper because facts and
        # providers have separate load contexts and must not depend on each other.
        def split_profile_list(value)
          return nil if value.nil? || value.strip.empty?

          result = value.split(',').map(&:strip).reject(&:empty?)
          result.empty? ? nil : result
        end
      end
    end
  end
end
