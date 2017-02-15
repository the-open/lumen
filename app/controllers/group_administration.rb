Lumen::App.controllers do
  
  get '/groups/:slug/check' do
    site_admins_only!
    @group = Group.find_by(slug: params[:slug]) || not_found
    @group.check!
    redirect "/groups/#{@group.slug}"
  end   
  
  get '/groups/:slug/edit' do
    @group = Group.find_by(slug: params[:slug]) || not_found
    group_admins_only!
    erb :'groups/build'
  end
  
  post '/groups/:slug/edit' do
    @group = Group.find_by(slug: params[:slug]) || not_found
    group_admins_only!
    if @group.update_attributes(params[:group])
      flash[:notice] = "<strong>Great!</strong> The group was updated successfully."
      redirect "/groups/#{@group.slug}"
    else
      flash.now[:error] = "<strong>Oops.</strong> Some errors prevented the group from being saved."
      erb :'groups/build'
    end    
  end   
  
  get '/groups/:slug/emails' do
    @group = Group.find_by(slug: params[:slug]) || not_found
    group_admins_only!
    erb :'group_administration/emails'
  end
  
  post '/groups/:slug/emails' do
    @group = Group.find_by(slug: params[:slug]) || not_found
    group_admins_only!
    if @group.update_attributes(params[:group])
      flash[:notice] = "<strong>Great!</strong> The group emails were updated successfully."
      redirect "/groups/#{@group.slug}"
    else
      flash.now[:error] = "<strong>Oops.</strong> Some errors prevented the emails from being saved."
      erb :'group_administration/emails'
    end    
  end 
  
  get '/groups/:slug/conversations_requiring_approval' do
    @group = Group.find_by(slug: params[:slug]) || not_found
    group_admins_only!
    erb :'group_administration/conversations_requiring_approval'    
  end
   
  get '/groups/:slug/manage_members', :provides => [:html, :csv] do
    @group = Group.find_by(slug: params[:slug]) || not_found
    group_admins_only!
    @q = params[:q]
    @o = params[:o] ? params[:o].to_sym : :name
    @d = params[:d] ? params[:d].to_sym : :asc
    @admins_only = params[:admins_only]
    @not_yet_receiving_emails = params[:not_yet_receiving_emails]
    @accounts = Account.where(:id.in => (@admins_only ? @group.admins.pluck(:id) : @group.memberships.pluck(:account_id)))
    @accounts = @accounts.where(:id.nin => @group.memberships.where(:status => 'confirmed').pluck(:account_id)) if @not_yet_receiving_emails
    @accounts = @accounts.or([{:name => /#{Regexp.escape(@q)}/i}, {:email => /#{Regexp.escape(@q)}/i}]) if @q
    @accounts = @accounts.order("#{@o} #{@d}")    
    @cols = {'Name' => :name, 'Email' => :email, 'Phone' => nil, 'Twitter' => nil, 'Affiliations' => nil, I18n.t(:account_tagships).capitalize => nil, 'Joined' => nil, 'Last signed in' => nil, 'Actions' => nil, 'Notifications' => nil}
    case content_type
    when :html    
      @accounts = @accounts.page(params[:page])      
      erb :'group_administration/manage_members'
    when :csv
      CSV.generate do |csv|
        csv << @cols.keys[0..-3]
        @accounts.each do |account|
          membership = @group.memberships.find_by(account: account)
          csv << [
            account.name,
            account.email,
            account.phone,
            account.twitter_profile_url ? account.twitter_profile_url.split('.com/')[1] : '',
            account.affiliations.map { |affiliation| "#{affiliation.title} at #{affiliation.organisation.name}" }.join("\n"),
            account.account_tagships.map { |account_tagship| account_tagship.account_tag.name }.join("\n"),
            membership.created_at.to_s(:db),
            (sign_in = account.sign_ins.order_by(:created_at.desc).limit(1).first) ? sign_in.created_at.to_s(:db) : "Never signed in"            
          ]
        end
      end       
    end
  end
  
  get '/groups/:slug/membership_requests' do
    @group = Group.find_by(slug: params[:slug]) || not_found
    group_admins_only!
    @q = params[:q]
    @o = params[:o] ? params[:o].to_sym : :created_at
    @d = params[:d] ? params[:d].to_sym : :desc
    @membership_requests = @group.membership_requests.where(:status => 'pending')
    @membership_requests = @membership_requests.where(:account_id.in => Account.or([{:name => /#{Regexp.escape(@q)}/i}, {:email => /#{Regexp.escape(@q)}/i}]).pluck(:id)) if @q
    @membership_requests = @membership_requests.order("#{@o} #{@d}")
    @cols = {'Name' => nil, 'Email' => nil}
    (@cols['Answers'] = nil) if @group.request_questions
    @cols.merge!({'Requested' => :created_at, 'Actions' => nil})
    @membership_requests = @membership_requests.page(params[:page])
    erb :'group_administration/membership_requests'
  end  
   
  get '/groups/:slug/remove_member/:account_id' do
    @group = Group.find_by(slug: params[:slug]) || not_found
    group_admins_only!
    @membership = @group.memberships.find_by(account_id: params[:account_id])
    @membership.destroy
    flash[:notice] = "#{@membership.account.name} was removed from the group"
    redirect back
  end 
  
  get '/groups/:slug/receive_membership_requests/:account_id' do
    @group = Group.find_by(slug: params[:slug]) || not_found
    group_admins_only!
    @membership = @group.memberships.find_by(account_id: params[:account_id])
    @membership.update_attribute(:receive_membership_requests, true)
    flash[:notice] = "#{@membership.account.name} will now be notified of membership requests"
    redirect back
  end   
  
  get '/groups/:slug/stop_receiving_membership_requests/:account_id' do
    @group = Group.find_by(slug: params[:slug]) || not_found
    group_admins_only!
    @membership = @group.memberships.find_by(account_id: params[:account_id])
    @membership.update_attribute(:receive_membership_requests, false)
    flash[:notice] = "#{@membership.account.name} will no longer be notified of membership requests"
    redirect back
  end   
  
  get '/groups/:slug/make_admin/:account_id' do
    @group = Group.find_by(slug: params[:slug]) || not_found
    group_admins_only!
    @membership = @group.memberships.find_by(account_id: params[:account_id])
    @membership.update_attribute(:admin, true)
    flash[:notice] = "#{@membership.account.name} was made an admin"
    redirect back
  end   
  
  get '/groups/:slug/unadmin/:account_id' do
    @group = Group.find_by(slug: params[:slug]) || not_found
    group_admins_only!
    @membership = @group.memberships.find_by(account_id: params[:account_id])
    @membership.update_attribute(:admin, false)
    @membership.update_attribute(:receive_membership_requests, false)
    flash[:notice] = "#{@membership.account.name}'s admin rights were revoked"
    redirect back
  end   
  
  get '/groups/:slug/mute/:account_id' do
    @group = Group.find_by(slug: params[:slug]) || not_found
    group_admins_only!
    @membership = @group.memberships.find_by(account_id: params[:account_id])
    @membership.update_attribute(:muted, true)
    flash[:notice] = "#{@membership.account.name} was muted"
    redirect back
  end   
  
  get '/groups/:slug/unmute/:account_id' do
    @group = Group.find_by(slug: params[:slug]) || not_found
    group_admins_only!
    @membership = @group.memberships.find_by(account_id: params[:account_id])
    @membership.update_attribute(:muted, false)
    flash[:notice] = "#{@membership.account.name} was unmuted"
    redirect back
  end     

  get '/groups/:slug/set_notification_level/:account_id' do
    @group = Group.find_by(slug: params[:slug]) || not_found
    group_admins_only!
    @membership = @group.memberships.find_by(account_id: params[:account_id])
    @membership.update_attribute(:notification_level, params[:level])
    flash[:notice] =  "#{@membership.account.name}'s notification options were updated"
    redirect back
  end   
  
  post '/groups/:slug/invite' do 
    @group = Group.find_by(slug: params[:slug]) || not_found
    group_admins_only!
    notices = []
    data = params[:data] || (params[:account_id] ? (account = Account.find(params[:account_id]); "#{account.name}\t#{account.email}") : "#{params[:name]}\t#{params[:email]}")
    data.split("\n").reject { |line| line.blank? }.each { |line|
      name, email = line.split("\t")
      if !email
        notices << "Please provide an email address for #{name}"
        next
      end
      name.strip!
      email.strip!
      
      if !(@account = Account.find_by(email: /^#{Regexp.escape(email)}$/i))   
        @account = Account.new({
            :name => name,
            :password => Account.generate_password(8),
            :email => email
          })
        @account.password_confirmation = @account.password
        if !@account.save
          notices << "Failed to create an account for #{email} - is this a valid email address?"
          next
        end
      end
      
      if @group.memberships.find_by(account: @account)
        notices << "#{email} is already a member of this group."
        next
      end
      
      @membership = @group.memberships.build :account => @account
      @membership.admin = true if params[:admin]
      @membership.status = 'confirmed' if params[:status] == 'confirmed'
      @membership.prevent_new_memberships = true if current_account.admin? and params[:prevent_new_memberships]
      @membership.added_by = current_account
      @membership.welcome_email_pending = true
      @membership.save
      notices << "#{email} was added to the group."
    }
    
    Delayed::Job.enqueue SendWelcomeEmailsJob.new(@group.id)
        
    flash[:notice] = notices.join('<br />') if !notices.empty?
    redirect back
  end
  
  get '/groups/:slug/reminder' do
    @group = Group.find_by(slug: params[:slug]) || not_found
    group_admins_only!
    membership = @group.memberships.find_by(account_id: params[:account_id])
    @account = membership.account
    @issue = case params[:issue].to_sym
    when :not_completed_signup
      "signed in to complete your profile"
    when :no_picture
      "uploaded a profile picture"
    when :no_affiliations
      "provided your organisational affiliations"      
    end
    
    group = @group # instance var not available in defaults block
    Mail.defaults do
      delivery_method :smtp, group.smtp_settings
    end    
    
    b = @group.reminder_email
    .gsub('[firstname]',@account.name.split(' ').first)
    .gsub('[admin]', current_account.name)
    .gsub('[issue]',@issue)
            
    mail = Mail.new
    mail.to = @account.email
    mail.from = "#{@group.slug} <#{@group.email('-noreply')}>"
    mail.cc = current_account.email
    mail.subject = @group.reminder_email_subject
    mail.html_part do
      content_type 'text/html; charset=UTF-8'
      body b
    end
    mail.deliver    
    membership.update_attribute(:reminder_sent, Time.now)
    redirect back
  end
          
  get '/groups/:slug/didyouknows' do
    @group = Group.find_by(slug: params[:slug]) || not_found
    group_admins_only!       
    erb :'group_administration/didyouknows'
  end  
  
  post '/groups/:slug/didyouknows/new' do
    @group = Group.find_by(slug: params[:slug]) || not_found
    group_admins_only!
    @group.didyouknows.create :body => params[:body]
    redirect back
  end    
  
  get '/groups/:slug/didyouknows/:id/destroy' do
    @group = Group.find_by(slug: params[:slug]) || not_found
    group_admins_only!
    @group.didyouknows.find(params[:id]).destroy
    redirect back
  end 
  
  get '/groups/:slug/process_membership_request/:id' do
    @group = Group.find_by(slug: params[:slug]) || not_found
    group_admins_only!
    membership_request = @group.membership_requests.find(params[:id])    
    if params[:accept]
      account = membership_request.account           
      membership_request.update_attribute(:status, 'accepted')
      membership = @group.memberships.create(:account => account, :status => params[:status])            
      (flash[:error] = "The membership could not be created" and redirect back) unless membership.persisted?
      
      sign_in_details = ''
      if membership.status == 'pending'
        sign_in_details << "You need to sign in to start receiving email notifications. "
      end
        
      if account.sign_ins.count == 0
        password = Account.generate_password(8)
        account.update_attribute(:password, password) 
        sign_in_details << "Sign in at http://#{Config['DOMAIN']}/sign_in with the email address #{account.email} and the password #{password}"
      else
        sign_in_details << "Sign in at http://#{Config['DOMAIN']}/sign_in."
      end 
            
      group = @group # instance var not available in defaults block
      Mail.defaults do
        delivery_method :smtp, group.smtp_settings
      end      
      
      b = group.membership_request_acceptance_email
      .gsub('[firstname]',account.name.split(' ').first)
      .gsub('[sign_in_details]', sign_in_details)
              
      mail = Mail.new
      mail.to = account.email
      mail.from = "#{group.slug} <#{group.email('-noreply')}>"
      mail.subject = group.membership_request_acceptance_email_subject
      mail.html_part do
        content_type 'text/html; charset=UTF-8'
        body b
      end
      mail.deliver  

    else
      membership_request.update_attribute(:status, 'rejected')
    end
    redirect back
  end
  
  get '/groups/:slug/stats' do    
    @group = Group.find_by(slug: params[:slug]) || not_found
    group_admins_only!
    
    @from = params[:from] ? Date.parse(params[:from]) : 1.month.ago.to_date
    @to =  params[:to] ? Date.parse(params[:to]) : Date.today
    @all = params[:all]
      
    @c = {}    
    conversations = @group.visible_conversations    
    conversations = conversations.where(:created_at.gte => @from).where(:created_at.lt => @to+1)
    conversations.only(:id, :account_id).each_with_index { |conversation|
      @c[conversation.account_id] = [] if !@c[conversation.account_id]
      @c[conversation.account_id] << conversation.id
    }
        
    @cp = {}  
    conversation_posts = @group.visible_conversation_posts
    conversation_posts = conversation_posts.where(:created_at.gte => @from).where(:created_at.lt => @to+1)
    conversation_posts.only(:id, :account_id).each_with_index { |conversation_post|
      @cp[conversation_post.account_id] = [] if !@cp[conversation_post.account_id]
      @cp[conversation_post.account_id] << conversation_post.id    
    }
    
    @e = {}
    events = @group.events
    events = events.where(:created_at.gte => @from).where(:created_at.lt => @to+1)
    events.only(:id, :account_id).each { |event|
      @e[event.account_id] = [] if !@e[event.account_id]
      @e[event.account_id] << event.id
    }    
    
    erb :'group_administration/stats'    
  end   
        
end