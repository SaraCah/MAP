class Alert < BaseStorage

    def self.set_alert(alert_name, message)
        db[:alert].filter(:alert_name => alert_name).delete
        db[:alert].insert(:alert_name => alert_name,
                            :message => message)
    end

    def self.get_alert(alert_name)
        db[:alert].filter(:alert_name => alert_name).get(:message)
    end

    def self.delete_alert(alert_name)
        db[:alert].filter(:alert_name => alert_name).delete
    end

end