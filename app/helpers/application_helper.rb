# Methods added to this helper will be available to all templates in the application
module ApplicationHelper
  def link_to_function(name, function, html_options = {})
    onclick_tag = "#{html_options[:onclick]}; " if html_options[:onclick]
    onclick = "#{onclick_tag}#{function}; return false;"
    href = html_options[:href] || '#'

    content_tag(:a, name, html_options.merge(:href => href, :onclick => onclick))
  end

  # the same method is defined in hosts but we need to have this available in all views
  # because of plugins that are extending bulk actions menu, their actions don't use hosts controller
  def multiple_with_filter?
    params.key?(:search)
  end

  # this helper should be used to print date time in absolute form
  # It will also define a title with relative time information,
  # unless you pass show_relative_time_tooltip = false.
  # it supports two formats :short and :long
  # example of long is February 12, 2021 17:13
  # example of short is Aug 31, 12:52
  def date_time_absolute(time, format = :short, seconds = false, show_relative_time_tooltip = true)
    raise ArgumentError, "unsupported format '#{format}', use :long or :short" unless %w(long short).include?(format.to_s)

    component = (format == :short) ? 'ShortDateTime' : 'LongDateTime'
    mount_date_component(component, time, seconds, show_relative_time_tooltip)
  end

  # this helper should be used to print date time in relative form, e.g. "10 days ago",
  # it will also define a title with absolute time information
  def date_time_relative(time)
    mount_date_component('RelativeDateTime', time, false, false)
  end

  def date_time_absolute_value(time, format = :short)
    l(time, :format => format)
  end

  def date_time_relative_value(time)
    ((time > Time.now.utc) ? _('in %s') : _('%s ago')) % time_ago_in_words(time)
  end

  def date_time_unless_empty(time)
    return ''.html_safe unless time
    date_time_relative(time)
  end

  def iana_timezone
    Time.zone&.tzinfo&.name || 'UTC'
  end

  protected

  def generate_date_id
    timestamp = (Time.now.to_f * 10**7).to_i
    "datetime_#{timestamp}"
  end

  def mount_date_component(component, time, seconds, show_relative_time_tooltip)
    data = { date: time.try(:iso8601), defaultValue: _('N/A'), seconds: seconds, showRelativeTimeTooltip: show_relative_time_tooltip}

    react_component(component, data)
  end

  def contract(model)
    model.to_label
  end

  def show_habtm(associations)
    render :partial => 'common/show_habtm', :collection => associations, :as => :association
  end

  # Display a link if user is authorized, otherwise a string
  # +name+    : String to be displayed
  # +options+ : Hash containing options for authorized_for and link_to
  # +html_options+ : Hash containing html options for the link or span
  def link_to_if_authorized(name, options = {}, html_options = {})
    engine = options.delete(:engine) || main_app
    enable_link = authorized_for(options)
    if enable_link
      link_to name, engine.url_for(options.reverse_merge(only_path: true)), html_options
    else
      link_to_function name, nil, html_options.merge!(:class => "#{html_options[:class]} disabled", :disabled => true)
    end
  end

  # Display a link to JS function if user is authorized, otherwise a string
  # +name+    : String to be displayed
  # +options+ : Hash containing options for authorized_for and link_to
  # +html_options+ : Hash containing html options for the link or span
  def link_to_function_if_authorized(name, function, options = {}, html_options = {})
    if authorized_for(options)
      link_to_function name, function, html_options
    else
      link_to_function name, nil, html_options.merge!(:class => "#{html_options[:class]} disabled", :disabled => true)
    end
  end

  def display_delete_if_authorized(options = {}, html_options = {})
    text = options.delete(:text) || _("Delete")
    method = options.delete(:method) || :delete
    options = {:auth_action => :destroy}.merge(options)
    html_options = { :data => { :confirm => _('Are you sure?') }, :method => method }.merge(html_options)
    display_link_if_authorized(text, options, html_options)
  end

  # Display a link if user is authorized, otherwise nothing
  # +name+    : String to be displayed
  # +options+ : Hash containing options for authorized_for and link_to
  # +html_options+ : Hash containing html options for the link or span
  def display_link_if_authorized(name, options = {}, html_options = {})
    engine = options.delete(:engine) || main_app
    enable_link = authorized_for(options)
    if enable_link
      link_to(name, engine.url_for(options.reverse_merge(only_path: true)), html_options)
    else
      ""
    end
  end

  def new_link(name, options = {}, html_options = {})
    options[:action] = :new
    html_options[:class] = "btn btn-primary #{html_options[:class]}"
    display_link_if_authorized(name, options, html_options)
  end

  def csv_link(permitted: [])
    link_to(_('Export'), current_url_params(:permitted => permitted).merge(:format => :csv),
      {:title => _('Export to CSV'), :class => 'btn btn-default', 'data-no-turbolink' => true})
  end

  # renders a style=display based on an attribute properties
  def display?(attribute = true)
    "style=#{display(attribute)}"
  end

  def display(attribute)
    "display:#{attribute ? 'none' : 'inline'};"
  end

  # return our current model instance type based on the current controller
  # i.e. HostsController would return "host"
  def type
    controller_name.singularize
  end

  def checked_icon(condition)
    icon_text('check', '', :kind => 'fa') if condition
  end

  def locked_icon(condition, hovertext)
    ('<span class="glyphicon glyphicon-lock" title="%s"/>' % hovertext).html_safe if condition
  end

  def no_permissions?
    !User.current || @welcome || @missing_permissions
  end

  def searchable?
    return false if no_permissions?
    if (controller.action_name == "index") || (defined?(SEARCHABLE_ACTIONS) && SEARCHABLE_ACTIONS.include?(controller.action_name))
      controller.respond_to?(:auto_complete_search)
    end
  end

  def filter_columns?
    return false if no_permissions?
    controller_name == 'hosts' && controller.action_name == 'index'
  end

  def auto_complete_controller_name
    controller.respond_to?(:auto_complete_controller_name) ? controller.auto_complete_controller_name : controller_name
  end

  def sort(field, permitted: [], **kwargs)
    kwargs[:url_options] ||= current_url_params(permitted: permitted)
    super(field, **kwargs)
  end

  def help_button
    link_to(_("Help"), { :action => "welcome" }, { :class => 'btn btn-default' }) if File.exist?("#{Rails.root}/app/views/#{controller_name}/welcome.html.erb")
  end

  def method_path(method)
    controller = controller_name.start_with?('compute') ? 'hosts' : controller_name
    send("#{method}_#{controller}_path")
  end

  def edit_textfield(object, property, options = {})
    edit_inline(object, property, options)
  end

  def edit_textarea(object, property, options = {})
    edit_inline(object, property, options.merge({:type => "textarea"}))
  end

  def edit_select(object, property, options = {})
    edit_inline(object, property, options.merge({:type => "select"}))
  end

  def select_action_button(title, options = {}, *args)
    # the no-buttons code is needed for users with less permissions
    args = args.flatten.select(&:present?)
    return if args.blank?
    button_classes = %w(btn btn-default btn-action)
    button_classes << 'btn-primary' if options[:primary]

    content_tag(:div, options.merge(:class => 'btn-group')) do
      # single button
      if args.length == 1
        content_tag(:span, args[0], :class => button_classes).html_safe
      # multiple options
      else
        button_classes << 'dropdown-toggle'
        title = (title + " " + content_tag(:span, '', :class => 'caret'))
        button = link_to(title.html_safe, '#',
          :class => button_classes,
          :'data-toggle' => 'dropdown')
        dropdown_list = content_tag(:ul, :class => "dropdown-menu pull-right") do
          args.map { |option| content_tag(:li, option) }.join(" ").html_safe
        end
        button + dropdown_list
      end
    end
  end

  def action_buttons(*args)
    # the no-buttons code is needed for users with less permissions
    args = args.flatten.select(&:present?)
    return if args.blank?

    # single button
    if args.length == 1
      action = args[0].is_a?(Hash) ? args[0][:content] : args[0]
      return content_tag(:span, action.html_safe, :class => 'btn btn-sm btn-default')
    end

    # multiple buttons
    primary = args.delete_at(0).html_safe
    primary = content_tag(:span, primary, :class => 'btn btn-sm btn-default') if primary !~ /btn/

    content_tag(:div, :class => "btn-group") do
      primary + link_to(content_tag(:span, '', :class => 'caret'), '#', :class => "btn btn-default #{'btn-sm' if primary =~ /btn-sm/} dropdown-toggle", :'data-toggle' => 'dropdown') +
        content_tag(:ul, :class => "dropdown-menu pull-right") do
          args.map do |option|
            tag_options = nil
            if option.is_a?(Hash)
              content = option[:content]
              tag_options = option[:options]
            else
              content = option
            end
            content_tag(:li, content, tag_options)
          end.join(" ").html_safe
        end
    end
  end

  def avatar_image_tag(user, html_options = {})
    if user.avatar_hash.present?
      image_tag("avatars/#{user.avatar_hash}.jpg", html_options)
    elsif user.disabled?
      icon_text("ban", "", :kind => "fa", :class => html_options[:class], :title => _("This user is disabled and won't be able to perform any actions. You can edit the user to enable them again."))
    else
      icon_text("user #{html_options[:class]}", "", :kind => "fa")
    end
  end

  def show_parent?(obj)
    minimum_count = obj.new_record? ? 0 : 1
    base = obj.class.respond_to?(:completer_scope) ? obj.class.completer_scope(nil) : obj.class
    base.count > minimum_count
  end

  def documentation_button(section = "", options = {})
    url = documentation_url section, options
    link_to(icon_text('help', _('Documentation'), :kind => 'pficon'),
      url, :rel => 'external noopener noreferrer', :class => 'btn btn-default btn-docs', :target => '_blank')
  end

  def generate_links_for(sub_model)
    return _("None found") if sub_model.to_a.empty?
    sub_model.map { |model| link_to(model.to_label, { :controller => model.class.model_name.plural.downcase, :action => :index, :search => "name = \"#{model.name}\"" }) }.to_sentence
  end

  def resource_prev_url_with_search_filters
    prev_controller_url = session["redirect_to_url_#{controller_name}"].to_s
    return nil unless prev_controller_url.include?('search')
    prev_controller_url
  end

  private

  def edit_inline(object, property, options = {})
    helper     = options[:helper]
    value      = helper.nil? ? object.send(property) : send(helper, object)
    klass      = options[:class]
    update_url = options[:update_url] || url_for(object)
    type       = options[:type]
    title      = options[:title]
    placeholder = options[:placeholder]
    select_values = [true, false].include?(value) ? [_('Yes'), _('No')] : options[:select_values]

    editable(object, property, {:type => type, :title => title, :value => value, :class => klass, :source => select_values, :url => update_url, :placeholder => placeholder}.compact)
  end

  def documentation_url(section = nil, type: 'manual', **options)
    main_app.external_link_url(type: type, section: section, params: options)
  end

  def spinner(text = '', options = {})
    if text.present?
      "<p class='spinner-label'> #{text} </p><div id='#{options[:id]}' class='spinner spinner-xs spinner-inline #{options[:class]}'>
      </div>".html_safe
    else
      "<div id='#{options[:id]}' class='spinner spinner-xs #{options[:class]}'></div>".html_safe
    end
  end

  def hidden_spinner(text = '', options = {})
    if options[:class]
      options[:class] += " hide"
    else
      options[:class] = "hide"
    end
    spinner(text, options)
  end

  def hosts_count(resource_name = controller.resource_name)
    @hosts_count ||= HostCounter.new(resource_name)
  end

  def webpack_dev_server
    return unless Rails.configuration.webpack.dev_server.enabled
    javascript_include_tag "#{@dev_server}/webpack-dev-server.js"
  end

  def accessible_resource_records(resource, order = :name)
    klass = resource.to_s.classify.constantize
    klass = klass.with_taxonomy_scope_override(@location, @organization) if klass.include? Taxonomix
    klass.authorized.reorder(order)
  end

  def accessible_resource(obj, resource, order = :name, association: resource)
    list = accessible_resource_records(resource, order).to_a
    # we need to allow the current value even if it was filtered
    current = obj.public_send(association) if obj.respond_to?(association)
    list |= [current] if current.present?
    list
  end

  def accessible_related_resource(obj, relation, order: :name, where: nil)
    return [] if obj.blank?
    related = obj.public_send(relation)
    related = related.with_taxonomy_scope_override(@location, @organization) if obj.class.reflect_on_association(relation).klass.include?(Taxonomix)
    related.authorized.where(where).reorder(order)
  end

  def explicit_value?(field)
    return true if params[:action] == 'clone'
    return false unless params[:host]
    !!params[:host][field]
  end

  def user_set?(field)
    # if the host has no hostgroup
    return true unless @host&.hostgroup
    # when editing a host, the values are specified explicitly
    return true if params[:action] == 'edit'
    return true if params[:action] == 'clone'
    # check if the user set the field explicitly despite setting a hostgroup.
    params[:host] && params[:host][:hostgroup_id] && params[:host][field]
  end

  def toast_notifications_data
    selected_toast_notifications = flash.select { |key, _| key != 'inline' }

    selected_toast_notifications.map do |type, notification|
      notification.is_a?(Hash) ? notification : { :type => type, :message => notification }
    end
  end

  def flash_inline
    flash['inline'] || {}
  end

  def alert_class(type)
    type = :danger if type == :error
    "alert-#{type}"
  end

  def current_url_params(permitted: [])
    params.slice(*permitted.concat([:locale, :search, :per_page])).permit!
  end

  def app_metadata
    {
      UISettings: ui_settings,
      version: SETTINGS[:version].short,
      docUrl: documentation_url,
      location: Location.current && { id: Location.current.id, title: Location.current.title },
      organization: Organization.current && { id: Organization.current.id, title: Organization.current.title },
      user: User.current&.attributes&.slice('id', 'login', 'firstname', 'lastname', 'admin'),
      user_settings: {
        lab_features: Setting[:lab_features],
      },
    }.compact
  end

  def ui_settings
    {
      perPage: Setting['entries_per_page'],
      destroyVmOnHostDelete: Setting['destroy_vm_on_host_delete'],
      labFeatures: Setting[:lab_features],
      safeMode: Setting[:safemode_render],
      displayFqdnForHosts: Setting[:display_fqdn_for_hosts],
      displayNewHostsPage: Setting[:new_hosts_page],
    }
  end

  def current_host_details_path(host)
    Setting['host_details_ui'] ? host_details_page_path(host) : host_path(host)
  end

  def hosts_path(*args)
    if Setting[:new_hosts_page]
      new_hosts_index_page_path(*args)
    else
      super
    end
  end
end
