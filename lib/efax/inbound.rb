require 'nokogiri'
require 'base64'
require 'tempfile'
require 'date'

module EFax
  class InboundPostStatus
    SUCCESS = 1
  end

  class InboundPostRequest
    attr_reader :encoded_file_contents,
                :file_type,
                :ani,
                :account_id,
                :fax_name,
                :csid,
                :status,
                :mcfid,
                :page_count,
                :request_type,
                :date_received,
                :request_date,
                :barcodes,
                :barcode_pages

    alias_method :sender_fax_number, :ani

    def initialize(xml)
      doc            = Nokogiri::XML(xml)
      @encoded_file_contents = doc.at(:FileContents).inner_text
      @file_type     = doc.at(:FileType).inner_text.to_sym
      @ani           = doc.at(:ANI).inner_text
      @account_id    = doc.at(:AccountID).inner_text
      @fax_name      = doc.at(:FaxName).inner_text
      @csid          = doc.at(:CSID).inner_text
      @status        = doc.at(:Status).inner_text.to_i
      @mcfid         = doc.at(:MCFID).inner_text.to_i
      @page_count    = doc.at(:PageCount).inner_text.to_i
      @request_type  = doc.at(:RequestType).inner_text
      @date_received = datetime_to_time(DateTime.strptime("#{doc.at(:DateReceived).inner_text} -08:00", "%m/%d/%Y %H:%M:%S %z"))
      @request_date  = datetime_to_time(DateTime.strptime("#{doc.at(:RequestDate).inner_text} -08:00", "%m/%d/%Y %H:%M:%S %z"))
      @barcodes      = doc.xpath("//Barcode/Key").map { |key| key.inner_html }
      @barcode_pages = doc.xpath("//Barcode/AdditionalInfo/CodeLocation/PageNumber").map { |key| key.inner_html }
    end

    def file_contents
      @file_contents ||= Base64.decode64(encoded_file_contents)
    end

    def file
      @file ||= begin
        if defined?(Encoding)
          file = Tempfile.new(fax_name, {:encoding => 'ascii-8bit'})
        else
          file = Tempfile.new(fax_name)
        end
        file << file_contents
        file.rewind
        file
      end
    end

    def post_successful_message
      "Post Successful"
    end

    def self.receive_by_params(params)
      receive_by_xml(params[:xml] || params["xml"])
    end

    def self.receive_by_xml(xml)
      new(xml)
    end


    private

    def datetime_to_time(datetime)
      if datetime.respond_to?(:to_time)
        datetime.to_time
      else
        d = datetime.new_offset(0)
        d.instance_eval do
          Time.utc(year, mon, mday, hour, min, sec + sec_fraction)
        end.getlocal
      end
    end
  end
end
