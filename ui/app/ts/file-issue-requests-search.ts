/// <amd-module name='file-issue-requests-search'/>


import Vue from "vue";
import VueResource from "vue-resource";
Vue.use(VueResource);

declare var M: any; // Materialize on the window context

Vue.component('file-issue-requests-search', {
    template: `
<div>
    <div class="card">
        <div class="card-content">
            <form :action="path" method="get" ref="form">
                <div class="row">
                    <div class="col s12 m4">
                        <div class="input-field">
                            <select name="digital_request_status" v-model="selectedDigitalRequestStatus">
                                <option></option>
                                <option v-for="status in status_options" :value="status">{{status}}</option>
                            </select>
                            <label>Digital Request Status</label>
                        </div>
                    </div>
                    <div class="col s12 m4">
                        <div class="input-field">
                            <select name="physical_request_status" v-model="selectedPhysicalRequestStatus">
                                <option></option>
                                <option v-for="status in status_options" :value="status">{{status}}</option>
                            </select>
                            <label>Physical Request Status</label>
                        </div>
                    </div>
                    <div class="col s12 m4 ">
                        <div class="input-field">
                            <select name="sort" v-model="selectedSort">
                                <option value="id_asc">ID A-Z</option>
                                <option value="id_desc">ID Z-A</option>
                                <option value="request_type_asc">Request Type A-Z</option>
                                <option value="request_type_desc">Request Type Z-A</option>
                                <option value="digital_request_status_asc">Digital Request Status A-Z</option>
                                <option value="digital_request_status_desc">Digital Request Status Z-A</option>
                                <option value="physical_request_status_asc">Physical Request Status A-Z</option>
                                <option value="physical_request_status_desc">Physical Request Status Z-A</option>
                                <option value="created_asc">Created Old-New</option>
                                <option value="created_desc">Created New-Old</option>
                            </select>
                            <label>Sort By</label>
                        </div>
                    </div>
                </div>
               <div class="row">
                    <div class="col s12">
                        <button class="btn btn-small">Search Requests</button>
                        <a href="/file-issue-requests" class="btn btn-small">Reset</a>
                    </div>
                </div>
            </form>
        </div>
    </div>
</div>
`,
    data: function(): {selectedSort: string, selectedDigitalRequestStatus: string, selectedPhysicalRequestStatus: string} {
        return {
            selectedSort: this.sort || 'id_asc',
            selectedDigitalRequestStatus: this.digital_request_status || undefined,
            selectedPhysicalRequestStatus: this.physical_request_status || undefined,
        };
    },
    props: ['path', 'sort', 'digital_request_status', 'physical_request_status', 'status_options'],
    methods: {
        submitForm: function() {
            (this.$refs.form as HTMLFormElement).submit();
        },
    },
    mounted: function() {
        M.FormSelect.init(this.$el.querySelectorAll('select'));
    },
});
