/// <amd-module name='file-issue-notifications'/>


import Vue from "vue";
import VueResource from "vue-resource";
Vue.use(VueResource);

declare var M: any; // Materialize on the window context

interface Notification {
    record_id: string;
    message: string;
    identifier: string;
    level: string;
}

Vue.component('file-issue-notifications', {
    template: `
<span class="notification">
    <template v-if="notifications.length > 0">
        <span class="yellow-text text-darken-3" :title="notifications.length + ' file issue notifications'" v-on:click="showNotifications()"><i aria-hidden="true" class="fa fa-flag"></i></span>
        <div ref="modal" class="modal">
            <div class="modal-content">
                <div class="card yellow lighten-4">
                    <div class="card-content" style="max-height: 200px; overflow: auto;">
                        <div v-for="notification in notifications">
                            <template v-if="notification.level === 'warning'">
                                <i aria-hidden="true" class="red-text darken-2 fa fa-exclamation-triangle"></i>
                            </template>
                            <strong>{{notification.identifier}}</strong>
                            {{notification.message}}
                            <a class="btn btn-small" :href="'/file-issues/' + notification.record_id">View</a>
                        </div>
                    </div>
                </div>
            </div>
            <div class="modal-footer">
                <a href="#!" class="modal-close waves-effect waves-green btn-flat">Close</a>
            </div>
        </div>
    </template>
</span>
`,
    data: function(): {notifications: Notification[]} {
        return {
            notifications: [],
        };
    },
    props: [],
    methods: {
        fetchNotifications: function() {
            this.$http.get('/file_issue_notifications')
            .then((response: any) => {
                return response.json();
            }, () => {
                this.notifications = [];
            }).then((json: any) => {
                this.notifications = json;
            });
        },
        showNotifications: function() {
            document.body.append(this.$refs.modal as Element);
            M.Modal.init(this.$refs.modal).open();
        },
    },
    mounted: function() {
        this.fetchNotifications();
    },
});
