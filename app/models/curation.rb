class Curation

  attr_reader :clearables

  def initialize(options)
    @clearables = []
    @user = options[:user]
    @association = options[:association]
    @data_object = options[:data_object] # TODO - Change association to a class, give it a #data_object, stop passing
    @vetted = options[:vetted] || @association.vetted
    @visibility = options[:visibility] || @association.visibility
    @comment = options[:comment]
    @untrust_reason_ids = options[:untrust_reason_ids]
    @hide_reason_ids = options[:hide_reason_ids]

    # Automatically hide it, if the curator made it untrusted:
    @visibility = Visibility.invisible if @vetted == Vetted.untrusted

    curate_association
  end

private

  def errors
    @errors = []
    @errors << 'nothing changed' unless something_needs_curation?
    @errors << 'object in preview state cannot be curated' if object_in_preview_state?
  end

  def object_in_preview_state?
    curated_object.visibility == Visibility.preview
  end

  # Aborts if nothing changed. Otherwise, decides what to curate, handles that, and logs the changes:
  # TODO - Really, I think we should report that nothing happened if nothing happened.  :|
  def curate_association
    # TODO - return unless errors.empty?
    return unless something_needs_curation?
    return if object_in_preview_state?
    handle_curation.each do |action|
      log = log_action(action)
      # Saves untrust reasons, if any
      unless @untrust_reason_ids.blank?
        save_untrust_reasons(log, action, @untrust_reason_ids)
      end
      unless @hide_reason_ids.blank?
        save_hide_reasons(log, action, @hide_reason_ids)
      end
      clear_cached_media_count_and_exemplar if action == :hide
    end
  end

  def something_needs_curation?
    vetted_changed? || visibility_changed?
  end

  def vetted_changed?
    @vetted_changed ||= @vetted && @association.vetted != @vetted
  end

  def visibility_changed?
    return @visibility_changed if @visibility_changed
    @visibility_changed = @visibility && (@association.visibility != @visibility)
    # TODO - gotta be a better way to do this...
    # Force a check of hide reasons if it was previously untrusted but now kept hidden
    @visibility_changed = (@association.visibility == Visibility.invisible && (@vetted == Vetted.trusted || @vetted == Vetted.unknown)) ? true : false unless @visibility_changed == true
    @visibility_changed
  end

  def curated_object
    @curated_object ||= if @association.class == UsersDataObject
        UsersDataObject.find_by_data_object_id(@data_object.latest_published_version_in_same_language.id)
      elsif @association.associated_by_curator
        CuratedDataObjectsHierarchyEntry.find_by_data_object_guid_and_hierarchy_entry_id(@data_object.guid, @association.id)
      else
        DataObjectsHierarchyEntry.find_by_data_object_id_and_hierarchy_entry_id(@data_object.latest_published_version_in_same_language.id, @association.id)
      end
  end

  # Figures out exactly what kind of curation is occuring, and performs it.  Returns an *array* of symbols
  # representing the actions that were taken.  ...which you may want to log.  :)
  def handle_curation
    object = curated_object
    actions = []
    actions << handle_vetting(object) if vetted_changed?
    actions << handle_visibility(object) if visibility_changed?
    return actions
  end

  def handle_vetting(object)
    if @vetted
      case @vetted
      when Vetted.untrusted
        raise "Curator should supply at least untrust reason(s) and/or curation comment" if (@untrust_reason_ids.blank? && @comment.nil?)
        object.untrust(@user)
        return :untrusted
      when Vetted.trusted
        if @visibility == Visibility.invisible && @hide_reason_ids.blank? && @comment.nil?
          raise "Curator should supply at least reason(s) to hide and/or curation comment"
        end
        object.trust(@user)
        return :trusted
      when Vetted.unknown
        if @visibility == Visibility.invisible && @hide_reason_ids.blank? && @comment.nil?
          raise "Curator should supply at least reason(s) to hide and/or curation comment"
        end
        object.unreviewed(@user)
        return :unreviewed
      else
        raise "Cannot set data object vetted id to #{@vetted.label}"
      end
    end
  end

  def handle_visibility(object)
    if @visibility
      case @visibility
      when Visibility.visible
        object.show(@user)
        return :show
      when Visibility.invisible
        if @vetted != Vetted.untrusted && @hide_reason_ids.blank? && @comment.nil?
          raise "Curator should supply at least reason(s) to hide and/or curation comment"
        end
        object.hide(@user)
        return :hide
      else
        raise "Cannot set data object visibility id to #{@visibility.label}"
      end
    end
  end

  def clear_cached_media_count_and_exemplar
    @clearables << @association
  end

  # TODO - wrong place for this logic; the curator activity log should handle these validations.
  def save_untrust_reasons(log, action, untrust_reason_ids)
    untrust_reason_ids.each do |untrust_reason_id|
      case untrust_reason_id.to_i
      when UntrustReason.misidentified.id
        log.untrust_reasons << UntrustReason.misidentified if action == :untrusted
      when UntrustReason.incorrect.id
        log.untrust_reasons << UntrustReason.incorrect if action == :untrusted
      else
        raise "Please re-check the provided untrust reasons"
      end
    end
  end

  def save_hide_reasons(log, action, hide_reason_ids)
    hide_reason_ids.each do |hide_reason_id|
      case hide_reason_id.to_i
      when UntrustReason.poor.id
        log.untrust_reasons << UntrustReason.poor if action == :hide
      when UntrustReason.duplicate.id
        log.untrust_reasons << UntrustReason.duplicate if action == :hide
      else
        raise "Please re-check the provided hide reasons"
      end
    end
  end

  # TODO - this was mostly stolen from data_objects controller. Generalize.
  def log_action(method)
    object = curated_object
    object_id = object.data_object_id if object.class.name == "DataObjectsHierarchyEntry" || object.class.name == "CuratedDataObjectsHierarchyEntry" || object.class.name == "UsersDataObject"
    return if object.blank?
    object_id = object.id if object_id.blank?

    if object.class.name == "DataObjectsHierarchyEntry" || object.class.name == "CuratedDataObjectsHierarchyEntry"
      he = object.hierarchy_entry
    elsif object.class.name == "HierarchyEntry"
      he = object
    # TODO - what if object is a UsersDataObject?  Why isn't it clear?
    end

    create_options = {
      :user_id => @user.id,
      :changeable_object_type => ChangeableObjectType.send(object.class.name.underscore.to_sym),
      :object_id => object_id,
      :activity => Activity.send(method),
      :data_object => @data_object,
      :data_object_guid => @data_object.guid,
      :hierarchy_entry => he,
      :created_at => 0.seconds.from_now
    }
    if object.class.name == "UsersDataObject"
      create_options.merge!(:taxon_concept_id => object.taxon_concept_id)
    end
    CuratorActivityLog.create(create_options)
  end

end
