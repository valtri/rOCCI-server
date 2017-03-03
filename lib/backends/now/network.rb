module Backends
  module Now
    #
    # Network backend using NOW component
    #
    class Network < Backends::Now::Base
      # Gets all network instance IDs, no details, no duplicates. Returned
      # identifiers must correspond to those found in the occi.core.id
      # attribute of ::Occi::Infrastructure::Network instances.
      #
      # @example
      #    list_ids #=> []
      #    list_ids #=> ["65d4f65adfadf-ad2f4ad-daf5ad-f5ad4fad4ffdf",
      #                             "ggf4f65adfadf-adgg4ad-daggad-fydd4fadyfdfd"]
      #
      # @param mixins [::Occi::Core::Mixins] a filter containing mixins
      # @return [Array<String>] IDs for all available network instances
      def list_ids(mixins = nil)
        list(mixins).to_a.map(&:id)
      end

      # Gets all network instances, instances must be filtered
      # by the specified filter, filter (if set) must contain an ::Occi::Core::Mixins instance.
      # Returned collection must contain ::Occi::Infrastructure::Network instances
      # wrapped in ::Occi::Core::Resources.
      #
      # @example
      #    networks = list #=> #<::Occi::Core::Resources>
      #    networks.first #=> #<::Occi::Infrastructure::Network>
      #
      #    mixins = ::Occi::Core::Mixins.new << ::Occi::Core::Mixin.new
      #    networks = list(mixins) #=> #<::Occi::Core::Resources>
      #
      # @param mixins [::Occi::Core::Mixins] a filter containing mixins
      # @return [::Occi::Core::Resources] a collection of network instances
      def list(mixins = nil)
        now_api = Backends::Now::Helpers::NowApi.new(@delegated_user['identity'], @options)
        networks = now_api.list
        occi_networks = networks.map { |network| raw2occi_network(network) }

        unless mixins.nil?
          occi_networks.select! { |n| (n.mixins & mixins).any? }
        end

        occi_networks
      end

      # Gets a specific network instance as ::Occi::Infrastructure::Network.
      # ID given as an argument must match the occi.core.id attribute inside
      # the returned ::Occi::Infrastructure::Network instance, however it is possible
      # to implement internal mapping to a platform-specific identifier.
      #
      # @example
      #    network = get('65d4f65adfadf-ad2f4ad-daf5ad-f5ad4fad4ffdf')
      #        #=> #<::Occi::Infrastructure::Network>
      #
      # @param network_id [String] OCCI identifier of the requested network instance
      # @return [::Occi::Infrastructure::Network, nil] a network instance or `nil`
      def get(network_id)
        now_api = Backends::Now::Helpers::NowApi.new(@delegated_user['identity'], @options)
        network = now_api.get(network_id)

        raw2occi_network(network)
      end

      # Instantiates a new network instance from ::Occi::Infrastructure::Network.
      # ID given in the occi.core.id attribute is optional and can be changed
      # inside this method. Final occi.core.id must be returned as a String.
      # If the requested instance cannot be created, an error describing the
      # problem must be raised, @see Backends::Errors.
      #
      # @example
      #    network = ::Occi::Infrastructure::Network.new
      #    network_id = create(network)
      #        #=> "65d4f65adfadf-ad2f4ad-daf5ad-f5ad4fad4ffdf"
      #
      # @param network [::Occi::Infrastructure::Network] network instance containing necessary attributes
      # @return [String] final identifier of the new network instance
      def create(network)
        @logger.info "[Backends] [NOW] Creating network #{network.inspect}"

        now_api = Backends::Now::Helpers::NowApi.new(@delegated_user['identity'], @options)

        raw_network = occi2raw_network(network.attributes)
        now_api.create(raw_network)
      end

      # Deletes all network instances, instances to be deleted must be filtered
      # by the specified filter, filter (if set) must contain an ::Occi::Core::Mixins instance.
      # If the requested instances cannot be deleted, an error describing the
      # problem must be raised, @see Backends::Errors.
      #
      # @example
      #    delete_all #=> true
      #
      #    mixins = ::Occi::Core::Mixins.new << ::Occi::Core::Mixin.new
      #    delete_all(mixins)  #=> true
      #
      # @param mixins [::Occi::Core::Mixins] a filter containing mixins
      # @return [true, false] result of the operation
      def delete_all(mixins = nil)
        now_api = Backends::Now::Helpers::NowApi.new(@delegated_user['identity'], @options)

        networks = now_api.list
        occi_networks = networks.map(&:raw2occi_network)

        unless mixins.nil?
          occi_networks.select! { |n| (n.mixins & mixins).any? }
        end
        @logger.info "[Backends] [NOW] Mass network delete of #{occi_networks.size} networks"

        occi_networks.each do |n|
          @logger.info "[Backends] [NOW] Deleting network #{n.inspect}"
          now_api.delete(n.id)
        end
      end

      # Deletes a specific network instance, instance to be deleted is
      # specified by an ID, this ID must match the occi.core.id attribute
      # of the deleted instance.
      # If the requested instance cannot be deleted, an error describing the
      # problem must be raised, @see Backends::Errors.
      #
      # @example
      #    delete("65d4f65adfadf-ad2f4ad-daf5ad-f5ad4fad4ffdf") #=> true
      #
      # @param network_id [String] an identifier of a network instance to be deleted
      # @return [true, false] result of the operation
      def delete(network_id)
        @logger.info "[Backends] [NOW] Deleting network #{network_id}"

        now_api = Backends::Now::Helpers::NowApi.new(@delegated_user['identity'], @options)
        now_api.delete(network_id)

        true
      end

      # Partially updates an existing network instance, instance to be updated
      # is specified by network_id.
      # If the requested instance cannot be updated, an error describing the
      # problem must be raised, @see Backends::Errors.
      #
      # @example
      #    attributes = ::Occi::Core::Attributes.new
      #    mixins = ::Occi::Core::Mixins.new
      #    links = ::Occi::Core::Links.new
      #    partial_update(network_id, attributes, mixins, links) #=> true
      #
      # @param network_id [String] unique identifier of a network instance to be updated
      # @param attributes [::Occi::Core::Attributes] a collection of attributes to be updated
      # @param mixins [::Occi::Core::Mixins] a collection of mixins to be added
      # @param links [::Occi::Core::Links] a collection of links to be added
      # @return [true, false] result of the operation
      def partial_update(network_id, attributes = nil, mixins = nil, links = nil)
        @logger.info "[Backends] [NOW] Updating network #{network_id} to #{attributes.inspect}"

        now_api = Backends::Now::Helpers::NowApi.new(@delegated_user['identity'], @options)

        raw_network = occi2raw_network(attributes)
        now_api.update(network_id, raw_network)

        true
      end

      # Updates an existing network instance, instance to be updated is specified
      # using the occi.core.id attribute of the instance passed as an argument.
      # If the requested instance cannot be updated, an error describing the
      # problem must be raised, @see Backends::Errors.
      #
      # @example
      #    network = ::Occi::Infrastructure::Network.new
      #    update(network) #=> true
      #
      # @param network [::Occi::Infrastructure::Network] instance containing updated information
      # @return [true, false] result of the operation
      def update(network)
        @logger.info "[Backends] [NOW] Updating network to #{network.inspect}"

        now_api = Backends::Now::Helpers::NowApi.new(@delegated_user['identity'], @options)

        raw_network = occi2raw_network(network.attributes)
        id = raw_network['id']
        now_api.update(id, raw_network)

        true
      end

      # Triggers an action on all existing network instance, instances must be filtered
      # by the specified filter, filter (if set) must contain an ::Occi::Core::Mixins instance,
      # action is identified by the action.term attribute of the action instance passed as an argument.
      # If the requested action cannot be triggered, an error describing the
      # problem must be raised, @see Backends::Errors.
      #
      # @example
      #    action_instance = ::Occi::Core::ActionInstance.new
      #    mixins = ::Occi::Core::Mixins.new << ::Occi::Core::Mixin.new
      #    trigger_action_on_all(action_instance, mixin) #=> true
      #
      # @param action_instance [::Occi::Core::ActionInstance] action to be triggered
      # @param mixins [::Occi::Core::Mixins] a filter containing mixins
      # @return [true, false] result of the operation
      def trigger_action_on_all(action_instance, mixins = nil)
        list_ids(mixins).each { |ntwrk| trigger_action(ntwrk, action_instance) }
        true
      end

      # Triggers an action on an existing network instance, the network instance in question
      # is identified by a network instance ID, action is identified by the action.term attribute
      # of the action instance passed as an argument.
      # If the requested action cannot be triggered, an error describing the
      # problem must be raised, @see Backends::Errors.
      #
      # @example
      #    action_instance = ::Occi::Core::ActionInstance.new
      #    trigger_action("65d4f65adfadf-ad2f4ad-daf5ad-f5ad4fad4ffdf", action_instance)
      #      #=> true
      #
      # @param network_id [String] network instance identifier
      # @param action_instance [::Occi::Core::ActionInstance] action to be triggered
      # @return [true, false] result of the operation
      def trigger_action(network_id, action_instance)
        raise Backends::Errors::ActionNotImplementedError,
              'No actions implemented!'
      end

      # Returns a collection of custom mixins introduced (and specific for)
      # the enabled backend. Only mixins and actions are allowed.
      #
      # @return [::Occi::Collection] collection of extensions (custom mixins and/or actions)
      def get_extensions
        # no extensions to include
        ::Occi::Collection.new
      end

      private

      def raw2occi_network(raw_network)
        network = ::Occi::Infrastructure::Network.new

        network.mixins << 'http://schemas.ogf.org/occi/infrastructure/network#ipnetwork'

        attrs = ::Occi::Core::Attributes.new
        attrs['occi.core.id']    = raw_network['id'].to_s
        attrs['occi.core.title'] = raw_network['title'] if raw_network.key? 'title'
        attrs['occi.core.summary'] = raw_network['description'] if raw_network.key? 'description'
        attrs['occi.network.vlan'] = raw_network['vlan'] if raw_network.key? 'vlan'
        if raw_network.key? 'range'
          range = raw_network['range']
          attrs['occi.network.address'] = range['address'] if range.key? 'address'
          attrs['occi.network.allocation'] = range['allocation'] if range.key? 'allocation'
          attrs['occi.network.gateway'] = range['gateway'] if range.key? 'gateway'
        end

        network.attributes.merge! attrs

        network
      end

      def occi2raw_network(attrs)
        raw = {}
        raw['id'] = attrs['occi.core.id']
        raw['title'] = attrs['occi.core.title'] if attrs['occi.core.title']
        raw['description'] = attrs['occi.core.summary'] if attrs['occi.core.summary']
        raw['vlan'] = attrs['occi.network.vlan'] if attrs['occi.network.vlan']

        range = {}
        range['address'] = attrs['occi.network.address'] if attrs['occi.network.address']
        range['allocation'] = attrs['occi.network.allocation'] if attrs['occi.network.allocation']
        range['gateway'] = attrs['occi.network.gateway'] if attrs['occi.network.gateway']
        raw['range'] = range unless range.empty?

        raw
      end
    end
  end
end