require 'net/http'
require 'net/https'
require 'builder'
require 'nokogiri'
require 'base64'

module Net #:nodoc:
  # Helper class for making HTTPS requests
  class HTTPS < HTTP
    def self.start(address, port = nil, p_addr = nil, p_port = nil, p_user = nil, p_pass = nil, &block) #:nodoc:
      https = new(address, port, p_addr, p_port, p_user, p_pass)
      https.use_ssl = true
      https.start(&block)
    end
  end
end

module EFax
  # URL of eFax web service
  Url      = "https://secure.efaxdeveloper.com/EFax_WebFax.serv"
  # URI of eFax web service
  Uri      = URI.parse(Url)
  # Prefered content type
  HEADERS  = {'Content-Type' => 'text/xml'}

  # Base class for OutboundRequest and OutboundStatus classes
  class Request
    def self.user
      EFax.configuration.username
    end

    def self.password
      EFax.configuration.password
    end

    def self.account_id
      EFax.configuration.account_id
    end

    def self.params(content)
      escaped_xml = ::URI.escape(content, Regexp.new("[^#{::URI::PATTERN::UNRESERVED}]"))
      "id=#{account_id}&xml=#{escaped_xml}&respond=XML"
    end

    private_class_method :params
  end

  class OutboundRequest < Request
    def self.post(options = {})
      recipient_name = options.fetch(:recipient_name)
      recipient_company_name = options.fetch(:recipient_company_name)
      recipient_fax_number = options.fetch(:recipient_fax_number)
      subject = options.fetch(:subject, '')
      content = options.fetch(:content)
      content_type = options.fetch(:content_type, :pdf)

      xml_request = xml(recipient_name, recipient_company_name, recipient_fax_number, subject, content, content_type)
      response = Net::HTTPS.start(EFax::Uri.host, EFax::Uri.port) do |https|
        https.post(EFax::Uri.path, params(xml_request), EFax::HEADERS)
      end
      OutboundResponse.new(response)
    end

    def self.xml(name, company, fax_number, subject, content, content_type = :html)
      xml_request = ""
      xml = Builder::XmlMarkup.new(:target => xml_request, :indent => 2 )
      xml.instruct! :xml, :version => '1.0'
      xml.OutboundRequest do
        xml.AccessControl do
          xml.UserName(self.user)
          xml.Password(self.password)
        end
        xml.Transmission do
          xml.TransmissionControl do
            xml.Resolution("STANDARD")
            xml.Priority("NORMAL")
            xml.SelfBusy("DISABLE")
            xml.FaxHeader(subject)
          end
          xml.DispositionControl do
            xml.DispositionLevel("NONE")
          end
          xml.Recipients do
            xml.Recipient do
              xml.RecipientName(name)
              xml.RecipientCompany(company)
              xml.RecipientFax(fax_number)
            end
          end
          xml.Files do
            xml.File do
              encoded_content = Base64.encode64(content).delete("\n")
              xml.FileContents(encoded_content)
              xml.FileType(content_type.to_s)
            end
          end
        end
      end
      xml_request
    end

    private_class_method :xml
  end

  class RequestStatus
    HTTP_FAILURE = 0
    SUCCESS      = 1
    FAILURE      = 2
  end

  class OutboundResponse
    attr_reader :status_code
    attr_reader :error_message
    attr_reader :error_level
    attr_reader :doc_id

    def initialize(response)  #:nodoc:
      if response.is_a? Net::HTTPOK
        doc = Nokogiri::XML(response.body)
        @status_code = doc.at(:StatusCode).inner_text.to_i
        @error_message = doc.at(:ErrorMessage)
        @error_message = @error_message.inner_text if @error_message
        @error_level = doc.at(:ErrorLevel)
        @error_level = @error_level.inner_text if @error_level
        @doc_id = doc.at(:DOCID).inner_text
        @doc_id = @doc_id.empty? ? nil : @doc_id
      else
        @status_code = RequestStatus::HTTP_FAILURE
        @error_message = "HTTP request failed (#{response.code})"
      end
    end
  end

  class OutboundStatus < Request
    def self.post(doc_id)
      data = params(xml(doc_id))
      response = Net::HTTPS.start(EFax::Uri.host, EFax::Uri.port) do |https|
        https.post(EFax::Uri.path, data, EFax::HEADERS)
      end
      OutboundStatusResponse.new(response)
    end

    def self.xml(doc_id)
      xml_request = ""
      xml = Builder::XmlMarkup.new(:target => xml_request, :indent => 2 )
      xml.instruct! :xml, :version => '1.0'
      xml.OutboundStatus do
        xml.AccessControl do
          xml.UserName(self.user)
          xml.Password(self.password)
        end
        xml.Transmission do
          xml.TransmissionControl do
            xml.DOCID(doc_id)
          end
        end
      end
      xml_request
    end

    private_class_method :xml
  end

  class QueryStatus
    HTTP_FAILURE = 0
    PENDING      = 3
    SENT         = 4
    FAILURE      = 5
  end

  class OutboundStatusResponse
    attr_reader :status_code
    attr_reader :message
    attr_reader :classification
    attr_reader :outcome

    def initialize(response) #:nodoc:
      if response.is_a? Net::HTTPOK
        doc = Nokogiri::XML(response.body)
        @message = doc.at(:Message).inner_text
        @classification = doc.at(:Classification).inner_text.delete('"')
        @outcome = doc.at(:Outcome).inner_text.delete('"')
        if !sent_yet?(classification, outcome) || busy_signal?(classification)
          @status_code = QueryStatus::PENDING
        elsif @classification == "Success" && @outcome == "Success"
          @status_code = QueryStatus::SENT
        else
          @status_code = QueryStatus::FAILURE
        end
      else
        @status_code = QueryStatus::HTTP_FAILURE
        @message = "HTTP request failed (#{response.code})"
      end
    end

    def busy_signal?(classification)
      classification == "Busy"
    end

    def sent_yet?(classification, outcome)
      !classification.empty? || !outcome.empty?
    end

  end
end
