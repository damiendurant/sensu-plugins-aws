#! /usr/bin/env ruby
#
# check-eni-status
#
# DESCRIPTION:
#   This plugin checks the status of an elastic network interface
#
# OUTPUT:
#   plain-text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: aws-sdk-v2
#   gem: sensu-plugin
#
# USAGE:
#   check-eni-status -e eni -w in-use -r region
#   check-eni-status -e eni -c available -r region
#
# NOTES:
#
# LICENSE:
#   Copyright (c) 2013, Damien DURANT <damien.durant@edifixio.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'sensu-plugins-aws'
require 'aws-sdk'

#
# Check ENI Status
#
class ENIStatus < Sensu::Plugin::Check::CLI
  include Common

  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default: 'us-east-1'

  option :eni,
         short: '-e ENI_ID',
         long: '--eni ENI_ID',
         description: 'A comma seperated list of the Elastic Network Interfaces to check',
         default: ''

  option :warn_status,
         short: '-w STATUS',
         long: '--warn STATUS',
         description: 'ENI status considered to be a warning',
         default: ''

  option :crit_status,
         short: '-c STATUS',
         long: '--crit STATUS',
         description: 'ENI status considered to be critical',
         default: ''

  def aws_config
    { access_key_id: config[:aws_access_key],
      secret_access_key: config[:aws_secret_access_key],
      region: config[:aws_region] }
  end

  def run
    Aws.config.update(aws_config)
    client = Aws::EC2::Client.new

    if config[:eni].empty?
        critical 'Error, ENI(s) should be specified.'
    end

    warnings = []
    crits = []
    passing = []

    eni = config[:eni].split(',')
    eni.each do |e|
      status = client.describe_network_interfaces(
         filters: [{ name: 'network-interface-id', values: [e] }]
      )[:network_interfaces].first
      
      unless status
        warnings << "No Information found for #{e}"
      else
        if config[:warn_status].casecmp status[:status]
          crits << "#{e} is #{status[:status]}"
        elsif config[:warn_status].casecmp status[:status]
          warnings << "#{e} is #{status[:status]}"
        end
      end
    end

    if crits.any?
      critical crits.join(', ').to_s
    elsif warnings.any?
      warning warnings.join(', ').to_s
    else
      ok "all queue(s): #{queues} are OK"
    end
  end
end