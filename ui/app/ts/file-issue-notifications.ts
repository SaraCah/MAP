/// <amd-module name='file-issue-notifications'/>


import Vue from "vue";
import VueResource from "vue-resource";
Vue.use(VueResource);

declare var M: any; // Materialize on the window context

interface FileIssueNotifications {
    file_issue_id: string;
    notifications: Notification[];
}

interface Notification {
    record_id: string;
    message: string;
    identifier: string;
    level: string;
}

Vue.component('file-issue-notifications', {
    template: `
<span class="notification">
    <template v-if="file_issues.length > 0">
        <a class="yellow-text text-darken-3" :title="'You have ' + file_issues.length + ' notifications'" v-on:click="showNotifications()"><i aria-hidden="true" class="fa fa-flag" style="font-size:16px;"></i></a>
        <div ref="modal" class="modal">
            <div class="modal-content">
                <div v-for="(file_issue, i) in file_issues" class="card yellow lighten-4">
                    <div class="card-content" style="max-height: 200px; overflow: auto;">
                        <a class="btn btn-small right" :href="'/file-issues/' + file_issue.record_id">View</a>
                        <span class="card-title">{{file_issue.identifier}}</span>
                        <div v-for="notification in file_issue.notifications">
                            <template v-if="notification.level === 'warning'">
                                <i aria-hidden="true" class="red-text darken-2 fa fa-exclamation-triangle"></i>
                            </template>
                            {{notification.message}}
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
    data: function(): {file_issues: FileIssueNotifications[]} {
        return {
            file_issues: [],
        };
    },
    props: [],
    methods: {
        fetchNotifications: function() {
            this.$http.get('/file_issue_notifications')
            .then((response: any) => {
                return response.json();
            }, () => {
                this.file_issues = [];
            }).then((json: any) => {
                this.file_issues = json;
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
