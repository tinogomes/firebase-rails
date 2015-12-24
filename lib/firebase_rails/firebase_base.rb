require 'firebase'

class FirebaseBase

  def is_firebase_class() end

  def save
    FirebaseBase.firebase_request(:update,
      "#{self.firebase_model}/#{self.id}",
      self.as_firebase_json
    )
  end

  def update(params)
    FirebaseBase.firebase_request(:update,
      "#{self.firebase_model}/#{self.id}",
      params
    )
  end

  def as_firebase_json
    removable_attrs = ["id", "firebase_model"]
    cloned_instance_vars = self.dup
    removable_attrs.each do |attr|
      if self.instance_variable_names.include?("@#{attr}")
        cloned_instance_vars.remove_instance_variable("@#{attr}")
      end
    end
    cloned_instance_vars.as_json
  end

  class << self

    # creates new firebase object based on params passed
    # and returns the id (firebase key) of the new firebase object
    def create(params)
      # firebase returns the new id (key) as "name". Stupid I think
      firebase_id = firebase_request(:push, firebase_model, params)["name"]
      firebase_hash = normalize_firebase_hash(params, firebase_id)
      create_firebase_object(firebase_hash)
    end

    def destroy_all
      firebase_response = firebase_request(:delete, "#{firebase_model}")
    end

    # takes firebase id (string), and returns single object body
    def find(id)
      firebase_response = firebase_request(:get, "#{firebase_model}/#{id}")
      firebase_hash = normalize_firebase_hash(firebase_response, id)
      create_firebase_object(firebase_hash)
    end

    def all
      firebase_response = firebase_request(:get, "#{firebase_model}")
      firebase_hashes_array = normalize_firebase_hashes(firebase_response)
      firebase_hashes_array.map{ |hash| create_firebase_object(hash) }
    end

    # firebase requires this type of encoding or it doesn't work
    # wack if you ask me, but it's in their docs somewhere
    def encode_init_value(value)
      if value.kind_of?(String)
        "\"#{value}\""
      elsif [true, false].include?(value)
        "#{value}"
      end
    end

    # takes a hash of key and values
    # and returns an array of objects
    def find_by(hash)
      # firebase does not have complex querying
      # so we have to grab all objects satisfying
      # first key/value
      init_key, init_value = hash.shift
      firebase_response = firebase_request(:get, firebase_model,
        :orderBy => "\"#{init_key}\"",
        :equalTo => encode_init_value(init_value)
      )

      # we then filter the remaining key/values with ruby
      hash.each do |k, v|
        firebase_response = firebase_response.select do |firebase_key, firebase_hash|
          firebase_hash[k.to_s] == v
        end
      end

      firebase_hashes_array = normalize_firebase_hashes(firebase_response)
      firebase_hashes_array.map{ |hash| create_firebase_object(hash) }
    end

    # DYNAMIC METHODS FOR ASSOCIATIONS

    def associations_hash
      @associations_hash ||= {
        has_many: [],
        belongs_to: []
      }
    end

    def associations_array
      @associations_array ||= associations_hash[:has_many].dup.concat(associations_hash[:belongs_to].dup)
    end

    def has_many(attr)
      associations_hash[:has_many] << attr.to_s

      define_method "set_#{attr}" do |args|
        args = [args] unless args.kind_of?(Array)
        firebase_object_ids_hash = {}
        args.each do |object_or_id|
          id = object_or_id.kind_of?(String) ? object_or_id : object_or_id.id
          firebase_object_ids_hash[id] = true
        end
        self.class.set_attr_accessor(self, attr, firebase_object_ids_hash.keys)
        FirebaseBase.firebase_request(:set,
          "#{self.firebase_model}/#{self.id}/#{attr}",
          firebase_object_ids_hash.as_json
        )
      end
    end

    def belongs_to(attr)
      associations_hash[:belongs_to] << attr.to_s

      define_method "set_#{attr}" do |args|
        if args.class.method_defined? :is_firebase_class
          self.class.set_attr_accessor(self, attr, args.id)
        else
          self.class.set_attr_accessor(self, attr, args)
        end
      end
    end

    def set_attr_accessor(object, key, value)
      object.class_eval { attr_accessor key.to_s }
      object.send("#{key.to_s}=", value)
    end

    def firebase_request(verb, path, params=nil)
      response = firebase_client.send(verb, path, params).body

      # firebase returns nil after successfully deleting records
      if verb == :delete && !response
        return true
      end

      # if nil is returned firebase could not find the specified id
      if verb != :delete && !response
        throw "No object found at path: '#{path}'"
      end

      # specific error was thrown from firebase
      if response["error"]
        throw response["error"] if response["error"]
      end

      response
    end

    def firebase_client
      @firebase_client ||= Firebase::Client.new("https://#{firebase_database_name}.firebaseio.com/")
    end

    def firebase_database_name
      name = Rails.configuration.x.firebase_name
      throw "No firebase_name was found in the configurations" if name.empty?
      name
    end

    def firebase_model
      @firebase_model ||= self.to_s.underscore.gsub(/^firebase_/, '').pluralize
    end

    def normalize_firebase_hashes(objects_array)
      objects_array.map{ |object| normalize_firebase_hash(object) }
    end

    # we want to return every firebase object with the id (key)
    # included in a single hash.
    # Firebase returns object as arrays with the if as index 0
    # and data as index 1.
    def normalize_firebase_hash(object, id=nil)
      # firebase returns objects like this: ["-K6BRIuIfaHFb9aZDP7I", {"name"=>"Jordan", "age"=>"27"}]
      if object.kind_of?(Array)
        id = object[0]
        data = object[1]
        data.merge({"id" => id})
      elsif object.kind_of?(Hash) && id
        object.merge({"id" => id})
      end
    end

    def attr_accessors_hash(hash)
      new_hash = {
        firebase_model: firebase_model
      }
      # these are the keys that have values from the firebase object
      included_keys = hash.keys.map{ |key| key.to_s }

      # goes through the associations and sets attr_accessors for those
      # associations that werent included from the firebase object
      associations_hash[:belongs_to].each do |association|
        new_hash[association] = nil unless included_keys.include?(association)
      end
      associations_hash[:has_many].each do |association|
        new_hash[association] = [] unless included_keys.include?(association)
      end

      new_hash
    end

    def create_firebase_object(hash)
      firebase_object = self.new

      # takes all attributes from firebase and possible attributes from
      # associations and creates and sets attr_accessors for them
      hash.merge(attr_accessors_hash(hash)).each do |k, v|
        set_attr_accessor(firebase_object, k, v)
      end

      firebase_object
    end
  end
end

