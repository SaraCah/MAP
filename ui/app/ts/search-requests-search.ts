/// <amd-module name='search-requests-search'/>

import Vue from "vue";
import VueResource from "vue-resource";
Vue.use(VueResource);

declare var M: any; // Materialize on the window context

Vue.component('search-requests-search', {
    template: `
<div>
    <div class="card">
        <div class="card-content">
            <form :action="path" method="get" ref="form">
                <div class="row">
                    <div class="col s12 m4">
                        <div class="input-field">
                            <select name="status" v-model="selectedStatus">
                                <option></option>
                                <option v-for="status in status_options" :value="status">{{status}}</option>
                            </select>
                            <label>Status</label>
                        </div>
                    </div>
                    <div class="col s12 m4 ">
                        <div class="input-field">
                            <select name="sort" v-model="selectedSort">
                                <option value="id_asc">ID A-Z</option>
                                <option value="id_desc">ID Z-A</option>
                                <option value="status_asc">Status A-Z</option>
                                <option value="status_desc">Status Z-A</option>
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
                        <a href="/search-requests" class="btn btn-small">Reset</a>
                    </div>
                </div>
            </form>
        </div>
    </div>
</div>
`,
    data: function(): {selectedSort: string, selectedStatus: string} {
        return {
            selectedSort: this.sort || 'id_desc',
            selectedStatus: this.status || undefined,
        };
    },
    props: ['path', 'sort', 'status', 'status_options'],
    mounted: function() {
        M.FormSelect.init(this.$el.querySelectorAll('select'));
    },
});
