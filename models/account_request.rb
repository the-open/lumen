class AccountRequest
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, :type => String
  field :email, :type => String
  field :email_verified, :type => Boolean, :default => false
  field :approved, :type => Boolean, :default => false

  validates_presence_of :name, :email

  has_one :affiliation, :dependent => :destroy
  belongs_to :account

  def self.admin_fields
    {
      :name => {type: :text, edit: false},
      :email => {type: :text, edit: false},
      :affiliation_summary => {type: :text, edit: false},
      :email_verified => {type: :check_box, edit: false},
      :approved => {type: :check_box, edit: false}
    }
  end

  def affiliation_summary
    affiliation.summary if affiliation
  end

  after_create do
    Mail.defaults do
      delivery_method :smtp, Account.smtp_settings
    end
    if Config['MAIL_SERVER_ADDRESS']
      verification_link = "http://#{Config['DOMAIN']}/accounts/requests/verify/#{id}"
      body = %{
Please verify your email to complete the membership request process.<br>
<br>
<a href="#{verification_link}">#{verification_link}</a><br>
<br>
Thanks,<br>
<br>
The #{Config['SITE_NAME']} team.<br>
      }
      mail = Mail.new
      mail.to = email
      mail.from = "#{Config['SITE_NAME']} <#{Config['HELP_ADDRESS']}>"
      mail.subject = "#{Config['SITE_NAME']}: Email verification"
      mail.html_part do
        content_type 'text/html; charset=UTF-8'
        body body
      end
      mail.deliver
    end
  end

  def notify_new_request
    Mail.defaults do
      delivery_method :smtp, Account.smtp_settings
    end
    if Config['ACCOUNT_REQUESTS_EMAILS']
      body = %{
New account request added by #{name} from #{affiliation.organisation.name}.<br>
<br>
You can approve the request at: http://#{Config['DOMAIN']}/accounts/requests<br>
<br>
The #{Config['SITE_NAME']} team.<br>
      }
      mail = Mail.new
      mail.to = Config['ACCOUNT_REQUESTS_EMAILS']
      mail.from = "#{Config['SITE_NAME']} <#{Config['HELP_ADDRESS']}>"
      mail.subject = "#{Config['SITE_NAME']}: New Account Request"
      mail.html_part do
        content_type 'text/html; charset=UTF-8'
        body body
      end
      mail.deliver
    end
  end

end
