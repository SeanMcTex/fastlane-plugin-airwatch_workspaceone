require 'fastlane/action'
require_relative '../helper/airwatch_workspaceone_helper'

module Fastlane
  module Actions
    class RetireSpecificVersionAction < Action
      
      APP_VERSIONS_LIST_SUFFIX    = "/API/mam/apps/search?applicationtype=Internal&bundleid=%s"
      INTERNAL_APP_RETIRE_SUFFIX  = "/API/mam/apps/internal/%d/retire"
      
      $is_debug = false

      def self.run(params)
        UI.message("The airwatch_workspaceone plugin is working!")

        # check if debug is enabled
        $is_debug = params[:debug]

        if debug
          UI.message("---------------------------------------------")
          UI.message("RetireSpecificVersionAction debug information")
          UI.message("---------------------------------------------")
          UI.message(" host_url: #{params[:host_url]}")
          UI.message(" aw_tenant_code: #{params[:aw_tenant_code]}")
          UI.message(" b64_encoded_auth: #{params[:b64_encoded_auth]}")
          UI.message(" app_identifier: #{params[:app_identifier]}")
          UI.message(" version_number: #{params[:version_number]}")
        end

        $host_url         = params[:host_url]
        $aw_tenant_code   = params[:aw_tenant_code]
        $b64_encoded_auth = params[:b64_encoded_auth]
        app_identifier    = params[:app_identifier]
        version_number    = params[:version_number]

        # step 1: find app
        UI.message("------------------------------")
        UI.message("1. Finding active app versions")
        UI.message("------------------------------")

        app_versions = find_app(app_identifier)
        app_version_numbers = app_versions.map {|app_version| app_version.values[1]}
        UI.success("Found %d active app version(s)" % [app_versions.count])
        UI.success("Version number(s): %s" % [app_version_numbers])

        # step 2: retire specific version
        UI.message("--------------------------------")
        UI.message("2. Retiring specific app version")
        UI.message("--------------------------------")

        if app_version_numbers.include? version_number
          version_index = app_version_numbers.index(version_number)
          app_version_to_retire = app_versions[version_index]
          retire_app(app_version_to_retire)
        else
          UI.user_error!("A version with the given version number: %s does not exist on the console for this application or is already retired." % [version_number])
        end

        UI.success("Version %s successfully retired" % [version_number])
      end

      def self.find_app(app_identifier)
        # get the list of apps 
        data = list_app_versions(app_identifier)
        active_app_versions = Array.new

        data['Application'].each do |app|
          if app['Status'] == "Active"
            active_app_version = Hash.new
            active_app_version['Id'] = app['Id']['Value']
            active_app_version['Version'] = app['AppVersion']
            active_app_versions << active_app_version
          end
        end

        active_app_versions.sort_by! { |app_version| app_version["Id"] }
        return active_app_versions
      end

      def self.list_app_versions(app_identifier)
        require 'rest-client'
        require 'json'
        
        response = RestClient.get($host_url + APP_VERSIONS_LIST_SUFFIX % [app_identifier], {accept: :json, 'aw-tenant-code': $aw_tenant_code, 'Authorization': "Basic " + $b64_encoded_auth})

        if debug
          UI.message("Response code: %d" % [response.code])
          UI.message("Response body:")
          UI.message(response.body)
        end

        if response.code != 200
          UI.user_error!("There was an error in finding app versions. One possible reason is that an app with the bundle identifier given does not exist on Console.")
          exit
        end

        json = JSON.parse(response.body)
        return json
      end

      def self.retire_app(app_version)
        require 'rest-client'
        require 'json'

        body = {
          "applicationid" => app_version['Id']
        }

        UI.message("Starting to retire app version: %s" % [app_version['Version']])
        response = RestClient.post($host_url + INTERNAL_APP_RETIRE_SUFFIX % [app_version['Id']], body.to_json,  {accept: :json, 'aw-tenant-code': $aw_tenant_code, 'Authorization': "Basic " + $b64_encoded_auth})

        if debug
          UI.message("Response code: %d" % [response.code])
        end

        if response.code == 202
          UI.message("Successfully retired app version: %s" % [app_version['Version']])
        else
          json = JSON.parse(response.body)
          UI.message("Failed to retire app version: %s" % [app_version['Version']])
        end
      end

      def self.description
        "The main purpose of this action is to retire a specific version of an application. This action takes a string parameter where you can specify the version number to retire."
      end

      def self.authors
        ["Ram Awadhesh Sharan"]
      end

      def self.return_value
        # If your method provides a return value, you can describe here what it does
      end

      def self.details
        # Optional:
        "retire_specific_version - To retire specific version of an application on the AirWatch/Workspace ONE console."
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :host_url,
                                  env_name: "AIRWATCH_HOST_API_URL",
                               description: "Host API URL of the AirWatch/Workspace ONE instance without /API/ at the end",
                                  optional: false,
                                      type: String,
                              verify_block: proc do |value|
                                              UI.user_error!("No AirWatch/Workspace ONE Host API URl given, pass using `host_url: 'https://yourhost.com'`") unless value and !value.empty?
                                            end),

          FastlaneCore::ConfigItem.new(key: :aw_tenant_code,
                                  env_name: "AIRWATCH_API_KEY",
                               description: "API key or the tenant code to access AirWatch/Workspace ONE Rest APIs",
                                  optional: false,
                                      type: String,
                              verify_block: proc do |value|
                                              UI.user_error!("Api tenant code header is missing, pass using `aw_tenant_code: 'yourapikey'`") unless value and !value.empty?
                                            end),

          FastlaneCore::ConfigItem.new(key: :b64_encoded_auth,
                                  env_name: "AIRWATCH_BASE64_ENCODED_BASIC_AUTH_STRING",
                               description: "The base64 encoded Basic Auth string generated by authorizing username and password to the AirWatch/Workspace ONE instance",
                                  optional: false,
                                      type: String,
                              verify_block: proc do |value|
                                              UI.user_error!("The authorization header is empty or the scheme is not basic, pass using `b64_encoded_auth: 'yourb64encodedauthstring'`") unless value and !value.empty?
                                            end),

          FastlaneCore::ConfigItem.new(key: :app_identifier,
                                  env_name: "APP_IDENTIFIER",
                               description: "Bundle identifier of your app",
                                  optional: false,
                                      type: String,
                              verify_block: proc do |value|
                                              UI.user_error!("No app identifier given, pass using `app_identifier: 'com.example.app'`") unless value and !value.empty?
                                            end),

          FastlaneCore::ConfigItem.new(key: :version_number,
                                  env_name: "AIRWATCH_VERSION_NUMBER",
                               description: "Version number of the application to retire",
                                  optional: false,
                                      type: String,
                              verify_block: proc do |value|
                                              UI.user_error!("No version number given, pass using `version_number: '1.0'`") unless value and !value.empty?
                                            end),

          FastlaneCore::ConfigItem.new(key: :debug,
                                  env_name: "AIRWATCH_DEBUG",
                               description: "Debug flag, set to true to show extended output. default: false",
                                  optional: true,
                                 is_string: false,
                             default_value: false)
        ]
      end

      def self.is_supported?(platform)
        # Adjust this if your plugin only works for a particular platform (iOS vs. Android, for example)
        # See: https://docs.fastlane.tools/advanced/#control-configuration-by-lane-and-by-platform

        [:ios, :android].include?(platform)
        true
      end

      # helpers
      
      def self.debug
        $is_debug
      end

    end
  end
end