#encoding: utf-8
# NOTE - I had to change a whole bunch of "NOT IN" clauses because they weren't working (SPARQL syntax error in my
# version.)  I think this will be fixed in later versions (it works for PL), but for now, this seems to work.
class TaxonData < TaxonUserClassificationFilter

  DEFAULT_PAGE_SIZE = 30

  def self.search(options={})
    # only attribute is required, querystring may be left blank to get all usages of an attribute
    return nil if options[:attribute].blank?
    options[:per_page] ||= TaxonData::DEFAULT_PAGE_SIZE
    total_results = EOL::Sparql.connection.query(prepare_search_query(options.merge(:only_count => true))).first[:count].to_i
    results = EOL::Sparql.connection.query(prepare_search_query(options))
    taxon_data_set = TaxonDataSet.new(results)
    DataPointUri.preload_associations(taxon_data_set.data_point_uris, :taxon_concept =>
      [ { :preferred_common_names => :name },
        { :preferred_entry => { :hierarchy_entry => { :name => :ranked_canonical_form } } } ])
    WillPaginate::Collection.create(options[:page], options[:per_page], total_results) do |pager|
       pager.replace(taxon_data_set.data_point_uris)
    end
  end

  def self.prepare_search_query(options={})
    options[:per_page] ||= TaxonData::DEFAULT_PAGE_SIZE
    options[:page] ||= 1
    if options[:only_count]
      query = "SELECT COUNT(*) as ?count"
    else
      # this is strange, but in order to properly do sorts, limits, and offsets there should be a subquery
      # see http://virtuoso.openlinksw.com/dataspace/doc/dav/wiki/Main/VirtTipsAndTricksHowToHandleBandwidthLimitExceed
      query = "SELECT ?attribute ?value ?unit_of_measure_uri ?data_point_uri ?graph ?taxon_concept_id WHERE { "
      query += "SELECT ?attribute ?value ?unit_of_measure_uri ?data_point_uri ?graph ?taxon_concept_id"
    end
    query += " WHERE {
      GRAPH ?graph {
        ?data_point_uri a <#{DataMeasurement::CLASS_URI}> .
        ?data_point_uri dwc:measurementType ?attribute .
        ?data_point_uri dwc:measurementValue ?value .
        ?data_point_uri <#{Rails.configuration.uri_measurement_of_taxon}> ?measurementOfTaxon .
        FILTER ( ?measurementOfTaxon = 'true' ) .
        OPTIONAL {
          ?data_point_uri dwc:measurementUnit ?unit_of_measure_uri .
        } . "
    if options[:from] && options[:to]
      query += "FILTER(xsd:float(?value) >= #{options[:from]} AND xsd:float(?value) <= #{options[:to]}) . "
    elsif options[:querystring] && options[:querystring].is_numeric?
      query += "FILTER(xsd:float(?value) = #{options[:querystring]}) . "
    elsif options[:querystring] && ! options[:querystring].strip.empty?
      query += "FILTER(REGEX(?value, '#{options[:querystring]}', 'i')) . "
    end
    if options[:attribute]
      query += "?data_point_uri dwc:measurementType <#{options[:attribute]}> . "
    end
    query += "} .
      {
        ?data_point_uri dwc:occurrenceID ?occurrence_id .
        ?occurrence_id dwc:taxonID ?taxon_id .
        ?taxon_id dwc:taxonConceptID ?taxon_concept_id
      } UNION {
        ?data_point_uri dwc:taxonConceptID ?taxon_concept_id .
      } }"
    unless options[:only_count]
      if options[:sort] == 'asc'
        query += " ORDER BY ASC(xsd:float(?value))"
      elsif options[:sort] == 'desc'
        query += " ORDER BY DESC(xsd:float(?value))"
      end
      query += "} LIMIT #{options[:per_page]} OFFSET #{((options[:page].to_i - 1) * options[:per_page])}"
    end
    return query
  end

  def downloadable?
    ! get_data.empty?
  end

  def topics
    @topics ||= get_data.map { |d| d[:attribute] }.select { |a| a.is_a?(KnownUri) }.uniq.compact.map(&:name)
  end

  def categories
    get_data unless @categories
    @categories
  end

  def get_data
    return @taxon_data_set if @taxon_data_set
    taxon_data_set = TaxonDataSet.new(data, taxon_concept_id: taxon_concept.id, language: user.language)
    taxon_data_set.sort
    known_uris = taxon_data_set.collect{ |data_point_uri| data_point_uri.predicate_known_uri }.compact
    KnownUri.preload_associations(known_uris,
                                  [ { :toc_items => :translations },
                                    { :known_uri_relationships_as_subject => :to_known_uri },
                                    { :known_uri_relationships_as_target => :from_known_uri } ] )
    @categories = known_uris.flat_map(&:toc_items).uniq.compact
    @taxon_data_set = taxon_data_set
  end

  def get_data_for_overview
    picker = TaxonDataExemplarPicker.new(self)
    picker.pick(get_data)
  end

  private

  def data
    (measurement_data + association_data).delete_if { |k,v| k[:attribute].blank? }
  end

  def measurement_data(options = {})
    selects = "?attribute ?value ?unit_of_measure_uri ?data_point_uri ?graph ?taxon_concept_id"
    query = "
      SELECT DISTINCT #{selects}
      WHERE {
        GRAPH ?graph {
          ?data_point_uri a <#{DataMeasurement::CLASS_URI}> .
          ?data_point_uri dwc:measurementType ?attribute .
          ?data_point_uri dwc:measurementValue ?value .
          OPTIONAL {
            ?data_point_uri dwc:measurementUnit ?unit_of_measure_uri
          }
        } .
        {
          ?data_point_uri dwc:taxonConceptID <#{UserAddedData::SUBJECT_PREFIX}#{taxon_concept.id}> .
          ?data_point_uri dwc:taxonConceptID ?taxon_concept_id
        }
        UNION {
          ?data_point_uri dwc:occurrenceID ?occurrence .
          ?occurrence dwc:taxonID ?taxon .
          ?data_point_uri <#{Rails.configuration.uri_measurement_of_taxon}> ?measurementOfTaxon .
          FILTER ( ?measurementOfTaxon = 'true' ) .
          GRAPH ?resource_mappings_graph {
            ?taxon dwc:taxonConceptID <#{UserAddedData::SUBJECT_PREFIX}#{taxon_concept.id}> .
            ?taxon dwc:taxonConceptID ?taxon_concept_id
          }
        }
      }
      LIMIT 800"
    EOL::Sparql.connection.query(query)
  end

  def association_data(options = {})
    selects = "?attribute ?value ?target_taxon_concept_id ?inverse_attribute ?data_point_uri ?graph"
    query = "
      SELECT DISTINCT #{selects}
      WHERE {
        GRAPH ?resource_mappings_graph {
          ?taxon dwc:taxonConceptID <#{UserAddedData::SUBJECT_PREFIX}#{taxon_concept.id}> .
          ?value dwc:taxonConceptID ?target_taxon_concept_id
        } .
        GRAPH ?graph {
          ?occurrence dwc:taxonID ?taxon .
          ?target_occurrence dwc:taxonID ?value .
          ?data_point_uri a <#{DataAssociation::CLASS_URI}> .
          {
            ?data_point_uri dwc:occurrenceID ?occurrence .
            ?data_point_uri <#{Rails.configuration.uri_target_occurence}> ?target_occurrence .
            ?data_point_uri <#{Rails.configuration.uri_association_type}> ?attribute
          }
          UNION
          {
            ?data_point_uri dwc:occurrenceID ?target_occurrence .
            ?data_point_uri <#{Rails.configuration.uri_target_occurence}> ?occurrence .
            ?data_point_uri <#{Rails.configuration.uri_association_type}> ?inverse_attribute
          }
        } .
        OPTIONAL {
          GRAPH ?mappings {
            ?inverse_attribute owl:inverseOf ?attribute
          }
        }
      }
      LIMIT 800"
    EOL::Sparql.connection.query(query)
  end

end
