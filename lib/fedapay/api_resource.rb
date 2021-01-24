# frozen_string_literal: true

module FedaPay
  class APIResource < FedaPayObject
    include FedaPay::APIOperations::Request

    # A flag that can be set a behavior that will cause this resource to be
    # encoded and sent up along with an update of its parent resource. This is
    # usually not desirable because resources are updated individually on their
    # own endpoints, but there are certain cases, replacing a customer's source
    # for example, where this is allowed.
    attr_accessor :save_with_parent

    def self.class_name
      name.split('::')[-1]
    end

    def self.resource_url
      if self == APIResource
        raise NotImplementedError, 'APIResource is an abstract class.  You should perform actions on its subclasses (Charge, Customer, etc.)'
      end
      # Namespaces are separated in object names with periods (.) and in URLs
      # with forward slashes (/), so replace the former with the latter.
      "/#{self::OBJECT_NAME.downcase.tr('.', '/')}".pluralize
    end

    def self.resource_object_name
      if self == APIResource
        raise NotImplementedError, 'APIResource is an abstract class.  You should perform actions on its subclasses (Charge, Customer, etc.)'
      end

      "#{FedaPay.api_version}/#{self::OBJECT_NAME.downcase}"
    end

    def resource_url
      unless (id = self['id'])
        raise InvalidRequestError.new("Could not determine which URL to request: #{self.class} instance has invalid ID: #{id.inspect}", 'id')
      end
      "#{self.class.resource_url}/#{CGI.escape(id.to_s)}"
    end

    def resource_object_name
      "#{self.class.resource_object_name}".to_sym
    end

    def refresh
      resp, opts = request(:get, resource_url, @retrieve_params)
      initialize_from(resp.data[resource_object_name], opts)
    end

    def self.retrieve(id, opts = {})
      opts = Util.normalize_opts(opts)
      instance = new(id.to_s, opts)
      instance.refresh
      instance
    end
  end
end
