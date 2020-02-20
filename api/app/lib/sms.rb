class SMS

  INTERNATIONAL_PREFIX = AppConfig[:international_phone_prefix]

  REGION = AppConfig[:sns_region]
  ACCESS_KEY = AppConfig[:sns_access_key]
  ACCESS_SECRET = AppConfig[:sns_access_secret]

  def self.send(number:, message:, sender:)
    sns = Aws::SNS::Client.new(:region => REGION,
                               :credentials => Aws::Credentials.new(ACCESS_KEY, ACCESS_SECRET))

    sns.publish(phone_number: add_international_prefix(number),
                message: message,
                message_attributes: {
                  'DefaultSenderID' => {data_type: 'String', string_value: sender},
                  'DefaultSMSType' => {data_type: 'String', string_value: 'Transactional'},
                })

    $LOG.info("SMS delivered successfully")
  end

  def self.add_international_prefix(number)
    number = number.to_s.gsub(/[^0-9]/, '')

    if number.length != 10
      raise "Phone number not a valid Australian mobile number: #{number}"
    end

    INTERNATIONAL_PREFIX + number.gsub(/^0/, '')
  end

end
