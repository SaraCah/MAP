/// <amd-module name='transfer-sorter'/>


import Vue from "vue";
import VueResource from "vue-resource";
Vue.use(VueResource);

declare var M: any; // Materialize on the window context

Vue.component('transfer-sorter', {
    template: `
<form :action="path" method="get" ref="form">
    <div class="row">
        <div class="col s12 m3 right">
            <div class="input-field">
                <select name="sort" v-model="selectedSort" v-on:change="submitForm">
                    <option value="id_asc">ID A-Z</option>
                    <option value="id_desc">ID Z-A</option>
                    <option value="title_asc">Title A-Z</option>
                    <option value="title_desc">Title Z-A</option>
                    <option value="status_asc">Status A-Z</option>
                    <option value="status_desc">Status Z-A</option>
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
