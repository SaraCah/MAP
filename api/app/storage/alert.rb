class Alert < BaseStorage

    def self.set_alert(alert_name, message)
        db[:alert].filter(:alert_name => alert_name,
                        :message => message).delete
        db[:alert].insert(:alert_name => alert_name,
                            :message => message ).create
    end

    def self.get_alert(alert_name, message)
        db[:alert].filter(:alert_name => alert_name).get(:message)
    end
end