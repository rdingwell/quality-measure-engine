module QME
  module MapReduce

    # Computes the value of quality measures based on the current set of patient
    # records in the database
    class Executor
    
      # Create a new Executor for the supplied database connection
      def initialize(db)
        @db = db
      end

      # Retrieve a measure definition from the database
      # @param [String] measure_id value of the measure's id field
      # @param [String] sub_id value of the measure's sub_id field, may be nil for measures with only a single numerator and denominator
      # @return [Hash] a JSON hash of the encoded measure
      def measure_def(measure_id, sub_id=nil)
        measures = @db.collection('measures')
        if sub_id
          measures.find_one({'id'=>measure_id, 'sub_id'=>sub_id})
        else
          measures.find_one({'id'=>measure_id})
        end
      end

      # Compute the specified measure
      # @param [String] measure_id value of the measure's id field
      # @param [String] sub_id value of the measure's sub_id field, may be nil for measures with only a single numerator and denominator
      # @param [Hash] parameter_values a hash of the measure parameter values. Keys may be either a String or Symbol
      # @return [Hash] a hash of the measure result with Symbol keys: population, denominator, numerator, antinumerator and exclusions whose values are the count of patient records that meet the criteria for each component of the measure. Also included are keys: population_members, denominator_members, numerator_members, antinumerator_members and exclusions_members whose values are arrays of the patient record identifiers that meet the criteria for each component of the measure.
      def measure_result(measure_id, sub_id, parameter_values)
        measure = Builder.new(measure_def(measure_id, sub_id), parameter_values)

        records = @db.collection('records')
        results = records.map_reduce(measure.map_function, measure.reduce_function)
        result = results.find_one # only one key is used by map fn
        value = result['value']

        summary = {}
        %w(population denominator numerator antinumerator exclusions).each do |field|
          summary[field.intern] = value[field].length
          summary[(field+'_members').intern] = value[field]
        end
        summary
      end
      
      # Return a list of the measures in the database
      # @return [Hash] a hash with measure identifiers as the keys where each entry is a Hash containing the measure id, name and steward with a variants field that is an array of hashes containing a sub_id and subtitle for each variant.
      def all_measures
        result = {}
        measures = @db.collection('measures')
        measures.find().each do |measure|
          entry = result[measure['id']]
          if entry==nil
            entry = {:variants=>[]}
            %w(id name steward description category).each do |field|
              entry[field.intern] = measure[field]
            end
            result[entry[:id]] = entry
          end
          if measure['sub_id']
            entry[:variants] << {:sub_id=>measure['sub_id'], :subtitle=>measure['subtitle']}
          end
        end
        result
      end
    end
  end
end
