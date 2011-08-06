class Administrator::ContactSubjectController < AdminController

  layout 'left_menu'

  before_filter :set_layout_variables

  before_filter :restrict_to_admins

 def index

   @page_title = I18n.t("contact_us_topics")
   @contact_subjects = ContactSubject.find(:all,:order => 'title')

 end

 def edit

   @page_title = I18n.t("edit_contact_us_topic")
   @contact_subject = ContactSubject.find(params[:id])

 end

 def new

   @page_title = I18n.t("new_contact_us_topic")
   @contact_subject = ContactSubject.new

 end

 def create

   @contact_subject = ContactSubject.new(params[:contact_subject])
   if @contact_subject.save
     flash[:notice] = I18n.t("the_new_topic_was_created")
     redirect_to :action => 'index'
   else
     render :action => 'new'
   end

 end

 def update

   @contact_subject = ContactSubject.find(params[:id])
   if @contact_subject.update_attributes(params[:contact_subject])
      flash[:notice] = I18n.t("the_topic_was_updated")
      redirect_to :action => 'index'
   else
      render :action => 'edit'
  end

 end

private

  def set_layout_variables
    @page_title = $ADMIN_CONSOLE_TITLE
    @navigation_partial = '/admin/navigation'
  end

end
