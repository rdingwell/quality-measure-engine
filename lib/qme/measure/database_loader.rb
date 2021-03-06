require File.join(File.dirname(__FILE__),'measure_loader')

module QME
  module Database
  
    # Utility class for working with JSON files and the database
    class Loader
      # Create a new Loader. Database host and port may be set using the 
      # environment variables TEST_DB_HOST and TEST_DB_PORT which default
      # to localhost and 27017 respectively.
      # @param [String] db_name the name of the database to use
      def initialize(db_name)
        @db_name = db_name
        @db_host = ENV['TEST_DB_HOST'] || 'localhost'
        @db_port = ENV['TEST_DB_PORT'] ? ENV['TEST_DB_PORT'].to_i : 27017
      end
      
      # Lazily creates a connection to the database and initializes the
      # JavaScript environment
      # @return [Mongo::Connection]
      def get_db
        if @db==nil
          @db = Mongo::Connection.new(@db_host, @db_port).db(@db_name)
          QME::MongoHelpers.initialize_javascript_frameworks(@db)
        end
        @db
      end
      
      # Load a measure from the filesystem and save it in the database.
      # @param [String] measure_dir path to the directory containing a measure or measure collection document
      # @param [String] collection_name name of the database collection to save the measure into.
      # @return [Array] the stroed measures as an array of JSON measure hashes
      def save_measure(measure_dir, collection_name)
        measures = QME::Measure::Loader.load_measure(measure_dir)
        measures.each do |measure|
          save(collection_name, measure)
        end
        measures
      end
      
      # Save a JSON hash to the specified collection, creates the
      # collection if it doesn't already exist.
      # @param [String] collection_name name of the database collection
      # @param [Hash] json the JSON hash to save in the database 
      def save(collection_name, json)
        collection = get_db.create_collection(collection_name)
        collection.save(json)
      end
      
      # Drop a database collection
      # @param [String] collection_name name of the database collection
      def drop_collection(collection_name)
        get_db.drop_collection(collection_name)
      end
      
      
      # Save a bundle to the db,  this will save the bundle meta data, javascript extension functions and measures to 
      # the db in their respective loacations
      # @param [String] bundle_dir the bundle directory
      # @param [String] bundle_collection the collection to save the bundle meta_data and extension functions to
      # @param [String] measure_collection the collection to save the measures to, defaults to measures
      def save_bundle(bundle_dir,bundle_collection, measure_collection = 'measures')
        bundle = QME::Measure::Loader.load_bundle(bundle_dir)
        bundle[:bundle_data][:measures] = []
        b_id = save(bundle_collection,bundle[:bundle_data])
        measures = bundle[:measures]
        measures.each do |measure|
           measure[:bundle] = b_id
           m_id = save(measure_collection,measure)
           bundle[:bundle_data][:measures] << m_id
        end
        save(bundle_collection,bundle[:bundle_data])
        bundle[:bundle_data][:extensions].each do |ext|
          get_db.eval(ext)
        end
        bundle
      end
      
      
      def remove_bundle(bundle_id, bundle_collection = 'bundles', measure_collection = 'measures')
        bundle = get_db[bundle_collection].find_one(bundle_id)
        bundle['measures'].each do |measure|
          mes = get_db[measure_collection].find_one(measure)
          get_db[measure_collection].remove(mes)
        end
        get_db[bundle_collection].remove(bundle)
      end
    end
  end
end