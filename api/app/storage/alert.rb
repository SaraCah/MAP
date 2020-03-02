class Alert < BaseStorage

    def self.set_alert(alert_name, message)
        db[:alert].filter(:alert_name => alert_name,
        :message => message).delete
        db[:alert].insert(:alert_name => alert_name,
                            :message => message)
    end

    def self.get_alert(alert_name)
        db[:alert].filter(:alert_name => alert_name).get(:message)
    end

    # def self.alert_name(alert_name)
    #     db[:alert][:alert_name => alert_name]
    # end

    def self.delete_alert(alert_name)
        db[:alert].filter(:alert_name => alert_name).delete
    end

    # def self.get_message(message)
    #     db[:alert][:message => message][:id]
    # end

end