module EFax
  class Configuration
    # EFax API account id
    # Defaults to 0000.
    # @return [String]
    attr_accessor :account_id

    # EFax API username
    # Defaults test.
    # @return [String]
    attr_accessor :username
    # EFax API password
    # Defaults to test.
    # @return [String]
    attr_accessor :password
    # EFax API outbound Resolution
    # Defaults to test.
    # @return [String]
    attr_accessor :resolution
    # EFax API outbound Priority
    # Defaults to test.
    # @return [String]
    attr_accessor :priority
    # EFax API outbound SelfBusy
    # Defaults to test.
    # @return [String]
    attr_accessor :self_busy

    def initialize
      @account_id = '0000'
      @username = 'test'
      @password = 'test'
      @resolution = 'STANDARD'
      @priority = 'NORMAL'
      @self_busy = 'DISABLE'
    end
  end

  # @return [EFax::Configuration] EFax's current configuration
  def self.configuration
    @configuration ||= Configuration.new
  end

  # Set EFax's configuration
  # @param config [EFax::Configuration]
  def self.configuration=(config)
    @configuration = config
  end

  # Modify EFax's current configuration
  # @yieldparam [EFax::Configuration] config current Efax config
  # ```
  # EFax.configure do |config|
  #   config.account_id = '6666'
  # end
  # ```
  def self.configure
    yield configuration
  end
end
