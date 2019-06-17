/// <amd-module name='file-issue-sorter'/>


import Vue from "vue";
import VueResource from "vue-resource";
Vue.use(VueResource);

declare var M: any; // Materialize on the window context

Vue.component('file-issue-sorter', {
    template: `
<form :action="path" method="get" ref="form">
    <div class="row">
        <div class="col s12 m3 right">
            <div class="input-field">
                <select name="sort" v-model="selectedSort" v-on:change="submitForm">
                    <option value="id_asc">ID A-Z</option>
                    <option value="id_desc">ID Z-A</option>
                    <option value="request_type_asc">Request Type A-Z</option>
                    <option value="request_type_desc">Request Type Z-A</option>
                    <template v-if="path == '/file-issue-requests'">
                        <option value="digital_request_status_asc">Digital Request Status A-Z</option>
                        <option value="digital_request_status_desc">Digital Request Status Z-A</option>
                        <option value="physical_request_status_asc">Physical Request Status A-Z</option>
                        <option value="physical_request_status_desc">Physical Request Status Z-A</option>
                    </template>
                    <template v-if="path == '/file-issues'">
                        <option value="issue_type_asc">Issue Type A-Z</option>
                        <option value="issue_type_desc">Issue Type Z-A</option>
                        <option value="status_asc">Status A-Z</option>
                        <option value="status_desc">Status Z-A</option>
                    </template>
                    <option value="created_asc">Created Old-New</option>
                    <option value="created_desc">Created New-Old</option>
                </select>
                <label>Sort By</label>
            </div>
        </div>
    </div>
</form>
`,
    data: function(): {selectedSort: string} {
        return {
            selectedSort: this.sort || 'id_asc',
        };
    },
    props: ['path', 'sort'],
    methods: {
        submitForm: function() {
            (this.$refs.form as HTMLFormElement).submit();
        },
    },
    mounted: function() {
        M.FormSelect.init(this.$el.querySelectorAll('select'));
    }
});
