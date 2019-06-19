/// <amd-module name='notifications'/>


import Vue from "vue";
import VueResource from "vue-resource";
import Utils from "./utils";
Vue.use(VueResource);

declare var M: any; // Materialize on the window context

interface Notification {
    record_type: string;
    record_id: string;
    message: string;
    identifier: string;
    level: string;
    timestamp: number;
}

Vue.component('notifications', {
    template: `
<div class="notifications card">
    <div class="card-content">
        <div class="card-title">Notifications</div>
        <template v-if="notifications.length > 0">
            <table class="striped">
                <thead>
                    <th></th>
                    <th>Record</th>
                    <th>Notification</th>
                    <th>Time of Event</th>
                    <th></th>
                </thead>
                <tbody>
                    <tr v-for="notification in notifications">
                        <td>
                            <template v-if="notification.level === 'warning'">
                                <i aria-hidden="true" class="red-text darken-2 fa fa-exclamation-triangle"></i>
                            </template>
                        </td>
                        <td>{{notification.identifier}}</td>
                        <td>{{notification.message}}</td>
                        <td>{{formatTimestamp(notification.timestamp)}}</td>
                        <td><a class="btn btn-small" :href="urlFor(notification.record_type, notification.record_id)">View</a></td>
                    </tr>
                </tbody>
            </table>
        </template>
        <template v-else-if="loading">
            Loading...
        </template>
        <template v-else>
            <span class="grey-text">No new notifications.</span>
        </template>
    </div>
</div>
`,
    data: function(): {notifications: Notification[], loading: boolean} {
        return {
            notifications: [],
            loading: true,
        };
    },
    props: [],
    methods: {
        fetchNotifications: function() {
            this.$http.get('/notifications')
            .then((response: any) => {
                return response.json();
            }, () => {
                this.notifications = [];
                this.loading = false;
            }).then((json: any) => {
                this.notifications = json;
                this.loading = false;
            });
        },
        urlFor: function(recordType: string, recordId: string) {
            if (recordType === 'file_issue') {
                return "/file-issues/" + recordId;
            } else if (recordType === 'file_issue_request') {
                return "/file-issue-requests/" + recordId;
            } else if (recordType === 'transfer') {
                return "/transfers/" + recordId;
            } else if (recordType === 'transfer_proposal') {
                return "/transfer-proposals/" + recordId;
            } else if (recordType === 'user') {
                return "/users/edit?username=" + recordId;
            } else if (recordType === 'location') {
                return "/locations/" + recordId;
            }
            return "alert('ERROR');";
        },
        showNotifications: function() {
            document.body.append(this.$refs.modal as Element);
            M.Modal.init(this.$refs.modal).open();
        },
        formatTimestamp: function(epochTime: number) {
            const date = new Date(epochTime);
            if (date.getHours() === 0 && date.getMinutes() === 0 && date.getMilliseconds() === 0) {
                return date.toLocaleDateString();
            }
            return Utils.localDateForEpoch(epochTime);
        },
    },
    mounted: function() {
        this.fetchNotifications();
    },
});
