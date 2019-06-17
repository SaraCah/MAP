/// <amd-module name='locations-search'/>


import Vue from "vue";
import VueResource from "vue-resource";
Vue.use(VueResource);

declare var M: any; // Materialize on the window context

import Agency from "./linker";

Vue.component('locations-search', {
    template: `
<div>
    <div class="card">
        <div class="card-content">
            <form action="/locations" method="get">
                <div class="row">
                    <div class="col s12 m3">
                        <div class="input-field">
                            <input type="text" id="q" name="q" v-model="query"></input>
                            <label for="q">Search location name</label>
                        </div>
                    </div>
                    <div v-if="show_agency_filter" class="col s12 m3">
                        <agency-typeahead ref="agencyTypeahead" v-on:selected="handleAgencySelected"></agency-typeahead>
                        <input name="agency_ref" type="hidden" v-model="selectedAgencyRef"/>
                    </div>
                    <div class="col s12 m3">
                        <div class="input-field">
                            <select name="sort" v-model="selectedSort">
                                <option value="agency_asc">Agency A-Z</option>
                                <option value="agency_desc">Agency Z-A</option>
                                <option value="location_name_asc">Location name A-Z</option>
                                <option value="location_name_desc">Location name Z-A</option>
                                <option value="created_asc">Created Old-New</option>
                                <option value="created_desc">Created New-Old</option>
                            </select>
                            <label>Sort By</label>
                        </div>
                    </div>
                </div>
                <div class="row">
                    <div class="col s12">
                        <button class="btn btn-small">Search Locations</button>
                        <a href="/locations" class="btn btn-small">Reset</a>
                    </div>
                </div>
            </form>
        </div>
    </div>
</div>
`,
    data: function(): {query: string, selectedAgencyRef: string, selectedAgencyLabel: string, selectedSort: string} {
        return {
            query: this.q || '',
            selectedAgencyRef: this.agency_ref || undefined,
            selectedAgencyLabel: this.agency_label || undefined,
            selectedSort: this.sort || 'agency_asc',
        };
    },
    props: ['q', 'agency_ref', 'agency_label', 'show_agency_filter', 'sort'],
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
