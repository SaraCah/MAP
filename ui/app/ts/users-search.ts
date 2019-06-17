/// <amd-module name='users-search'/>


import Vue from "vue";
import VueResource from "vue-resource";
Vue.use(VueResource);

declare var M: any; // Materialize on the window context

import Agency from "./linker";

Vue.component('users-search', {
    template: `
<div>
    <div class="card">
        <div class="card-content">
            <form action="/users" method="get">
                <div class="row">
                    <div class="col s12 m3">
                        <div class="input-field">
                            <input type="text" id="q" name="q" v-model="query"></input>
                            <label for="q">Search username/name</label>
                        </div>
                    </div>
                    <div v-if="show_agency_filter" class="col s12 m3">
                        <div class="input-field">
                            <agency-typeahead ref="agencyTypeahead" v-on:selected="handleAgencySelected"></agency-typeahead>
                            <input name="agency_ref" type="hidden" v-model="selectedAgencyRef"/>
                        </div>
                    </div>
                    <div class="col s12 m3">
                        <div class="input-field">
                            <select name="role" v-model="selectedRole">
                                <option value=""></option>
                                <option value="SENIOR_AGENCY_ADMIN">Senior Agency Admin</option>
                                <option value="AGENCY_ADMIN">Agency Admin</option>
                                <option value="AGENCY_CONTACT">Agency Contact</option>
                            </select>
                            <label>Role</label>
                        </div>
                    </div>
                    <div class="col s12 m3">
                        <div class="input-field">
                            <select name="sort" v-model="selectedSort">
                                <option value="username_asc">Username A-Z</option>
                                <option value="username_desc">Username Z-A</option>
                                <option value="name_asc">Name A-Z</option>
                                <option value="name_desc">Name Z-A</option>
                                <option value="created_asc">Created Old-New</option>
                                <option value="created_desc">Created New-Old</option>
                            </select>
                            <label>Sort By</label>
                        </div>
                    </div>
                </div>
                <div class="row">
                    <div class="col s12">
                        <button class="btn btn-small">Search Users</button>
                        <a href="/users" class="btn btn-small">Reset</a>
                    </div>
                </div>
            </form>
        </div>
    </div>
</div>
`,
    data: function(): {query: string, selectedAgencyRef: string, selectedAgencyLabel: string, selectedRole: string, selectedSort: string} {
        return {
            query: this.q || '',
            selectedAgencyRef: this.agency_ref || undefined,
            selectedRole: this.role || undefined,
            selectedAgencyLabel: this.agency_label || undefined,
            selectedSort: this.sort || 'username_asc',
        };
    },
    props: ['q', 'agency_ref', 'agency_label', 'role', 'show_agency_filter', 'sort'],
    methods: {
        handleAgencySelected: function(agency: Agency) {
            this.selectedAgencyRef = agency.id;
            this.selectedAgencyLabel = agency.label;
            this.$nextTick(() => {
                (this.$refs.agencyTypeahead as any).setText(agency.label);
            });
        },
    },
    mounted: function() {
        M.FormSelect.init(this.$el.querySelectorAll('select'));
        this.$el.querySelectorAll('input,textarea,select').forEach(function(el) {
            if ((el as HTMLFormElement).value !== "") {
                if (el.nextElementSibling) {
                    el.nextElementSibling.classList.add('active');
                }
            }
        });

        if (this.selectedAgencyLabel) {
            (this.$refs.agencyTypeahead as any).setText(this.selectedAgencyLabel);
        }
    },
});
