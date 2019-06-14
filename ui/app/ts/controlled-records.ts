/// <amd-module name='controlled-records'/>


import Vue from "vue";
import VueResource from "vue-resource";
import Utils from "./utils";

Vue.use(VueResource);

declare var AppConfig: any;

export default interface Record {
    type: string;
    title: string;
    under_movement: boolean;
    types: string[];
    file_issue_allowed: boolean;
    id: string;
    uri: string;
    qsa_id: number;
    physical_representations_count: number;
    digital_representations_count: number;
}

interface Facet {
    value: string;
    label: string;
    field: string;
    count: number;
}

interface Filter {
    field: string;
    value: string;
}

interface SearchState {
    currentPage: number;
    facets: object;
    records: Record[];
    initialised: boolean;
    showNextPage: boolean;
    showPrevPage: boolean;
    queryString: string;
    startDate: string;
    endDate: string;
    availableFilters: object[];
    appliedFilters: Filter[];
    selectedSort: string;
    selectedSeriesId?: string;
    selectedSeriesLabel?: string;
}

Vue.component('controlled-records', {
    template: `
<div class="record-search">
  <div class="card" v-if="!initialised">
  </div>
  <div class="card" v-else-if="records.length === 0 && browseMode">
    <div class="card-content">
      <span class="card-title">No controlled records</span>
      <p>Your agency does not currently control any records.</p>
    </div>
  </div>
  <div class="card" v-else>
    <div class="card-content">
      <div class="row">
        <span class="card-title">{{title}}</span>

        <div class="search-box">
          <form v-on:submit.stop.prevent="search()">
            <section class="row" v-if="this.selectedSeriesId && this.selectedSeriesLabel">
                <div class="col s12">
                    <blockquote>Searching within series: {{selectedSeriesLabel}} [<a href="javascript:void(0);" @click="reset()">reset</a>]</blockquote>
                </div>
            </section>

            <section class="row">
                <div class="col s12 m6">
                    <div class="input-field">
                        <label for="q">Search for keywords/identifiers</label>
                        <input type="text" id="q" name="q"></input>
                    </div>
                </div>
                <div class="col s12 m6">
                  <span>between</span>
                  <div class="input-field inline">
                    <label for="start_date">Start date</label>
                    <input type="text" id="start_date" name="start_date"></input>
                    <span class="helper-text">YYYY-MM-DD</span>
                  </div>
                  <div class="input-field inline">
                    <label for="end_date">End date</label>
                    <input type="text" id="end_date" name="end_date"></input>
                    <span class="helper-text">YYYY-MM-DD</span>
                  </div>
                </div>
            </section>

            <div class="row">
                <div class="col s12">
                    <button class="btn">Search</button>
                    <button class="btn" v-on:click.stop.prevent="reset()">Reset</button>
                </div>
            </div>
          </form>
        </div>

        <template v-if="records.length === 0">
          <div class="no-results">
          <span class="card-title">No results found</span>
          <p>Your search did not match any results.</p>
          </div>
        </template>
        <template v-else>
          <div class="row">
            <div class="col s12 m12 l2 search-tools">
              <section class="sort-selector">
                <p>Sort by</p>
                <select id="select_sort" v-model='selectedSort' class="browser-default">
                  <option value="relevance">Relevance</option>
                  <option value="title_asc">Title A-Z</option>
                  <option value="title_desc">Title Z-A</option>
                  <option value="agency_asc">Agency Identifier A-Z</option>
                  <option value="agency_desc">Agency Identifier Z-A</option>
                  <option value="qsaid_asc">QSA Identifier A-Z</option>
                  <option value="qsaid_desc">QSA Identifier Z-A</option>
                </select>
              </section>

              <section v-for="filter in this.availableFilters">
                <p class="facet-title">{{filter.title}}</p>
                <table class="facets-table">
                  <tr v-for="(facet, idx) in facets[filter.field]">
                    <td v-if="isFilterApplied(facet) || facets[filter.field].length === 1" class="facet-value">
                        {{facet.label}}
                    </td>
                    <td v-else class="facet-value">
                      <a href="javascript:void(0);" @click.prevent.default="addFilter(facet)">{{facet.label}}</a>
                    </td>
                    <td class="facet-count" v-if="isFilterApplied(facet)"><a href="javascript:void(0)" @click.prevent.default="removeFilter(facet)"><i class="fa fa-times"></i></a></td>
                    <td v-else class="facet-count">{{facet.count}}</td>
                  </tr>
                </table>
              </section>

            </div>
            <div class="col s12 m12 l9 search-results">
              <table class="responsive-table">
                <thead>
                  <tr>
                    <th>Type</th>
                    <th>Title</th>
                    <th></th>
                    <th>Agency Identifier</th>
                    <th>QSA Identifier</th>
                    <th>Representations</th>
                    <th style="width: 180px"></th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="record in records">
                    <td>{{record.type}}</td>
                    <td>{{record.title}}</td>
                    <td><span class="badge" v-if="record.under_movement">under movement</span></td>
                    <td>{{record.agency_assigned_id}}</td>
                    <td>{{record.type}} {{record.qsa_id}}</td>
                    <td>
                      <span v-if="record.types.indexOf('representation') < 0">
                        {{record.physical_representations_count}} physical; {{record.digital_representations_count}} digital
                      </span>
                    </td>
                    <td>
                        <a href="javascript:void(0);" @click="searchWithinSeries(record)" v-if="record.primary_type === 'resource' && !selectedSeriesId">Search&nbsp;within&nbsp;series</a>
                        <slot name="record_actions" v-bind:record="record"></slot>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </template>
      </div>
      <div class="row">
        <div class="col s12 center-align">
          <a :style="showPrevPage ? 'visibility: visible' : 'visibility: hidden'" href="javascript:void(0)" v-on:click.stop.prevent="prevPage()"><i class="fa fa-chevron-left"></i> Previous</a>
          <a :style="showNextPage ? 'visibility: visible' : 'visibility: hidden'" href="javascript:void(0)" v-on:click.stop.prevent="nextPage()">Next <i class="fa fa-chevron-right"></i></a>
        </div>
      </div>
    </div>
  </div>
</div>
`,
  data: function(): SearchState {
        return {
            initialised: false,
            currentPage: 0,
            records: [],
            facets: [],
            showNextPage: false,
            showPrevPage: false,
            queryString: '',
            startDate: '',
            endDate: '',
            availableFilters: [{field: 'primary_type', title: 'Record Types'},
                               {field: 'series', title: 'Series'}],
            appliedFilters: [],
            selectedSort: 'relevance',

            selectedSeriesId: undefined,
            selectedSeriesLabel: undefined,
        };
    },
    props: {
        title: String,
    },
    methods: {
        setHash: function() {
            const keyComponents = [
                ['q', this.queryString],
                ['startDate', this.startDate],
                ['endDate', this.endDate],
                ['currentPage', this.currentPage],
                ['appliedFilters', this.serializedFilters],
                ['sort', this.selectedSort],
                ['series', this.selectedSeriesId],
            ];

            const key = encodeURIComponent(JSON.stringify(Utils.filter(keyComponents, (bits) => !!bits[1])));

            window.location.hash = key;
        },
        applyHashChange: function() {
            const map: any = {};
            const hash = decodeURIComponent(window.location.hash).substring(1);

            if (hash.length > 0) {
                try {
                    for (const v of JSON.parse(hash)) {
                        map[v[0]] = v[1];
                    }
                } catch (e) {
                    // something not right, take defaults
                }
            }

            this.queryString = map.q || '';
            this.startDate = map.startDate || '';
            this.endDate = map.endDate || '';
            this.currentPage = map.currentPage ? Number(map.currentPage) : 0;
            this.selectedSort = map.sort || 'relevance';
            this.selectedSeriesId = map.series || undefined;

            this.loadFilters(map.appliedFilters || '[]');

            this.getRecords();
        },
        searchWithinSeries: function(record: Record) {
            this.selectedSeriesId = record.uri;
            this.setHash();
        },
        addFilter: function(facet: Facet) {
            this.appliedFilters.push(facet);
            this.setHash();
        },
        removeFilter: function(facet: Facet) {
            this.appliedFilters = Utils.filter(this.appliedFilters,
                                               (elt: Filter) => !((elt.field === facet.field) && (elt.value === facet.value)));
            this.setHash();
        },
        isFilterApplied: function(facet: Facet): boolean {
            return !!Utils.find(this.appliedFilters,
                                (elt: Filter) => (elt.field === facet.field) && (elt.value === facet.value));
        },
        search: function() {

            // We defer reading from the inputs (rather than binding them
            // directly to model values) because the user's search isn't "locked
            // in" until they fire the search.
            //
            // One place this matters is if you edit your search string but then
            // click "next page" on your set of existing results.  You would
            // expect your changes to the query to be discarded.
            this.queryString = (this.$el.querySelector('input[name="q"]') as HTMLInputElement).value;
            this.startDate = (this.$el.querySelector('input[name="start_date"]') as HTMLInputElement).value;
            this.endDate = (this.$el.querySelector('input[name="end_date"]') as HTMLInputElement).value;

            this.appliedFilters = [];
            this.currentPage = 0;
            this.selectedSort = 'relevance';

            this.setHash();
        },
        reset: function() {
            this.queryString = '';
            this.startDate = '';
            this.endDate = '';
            this.currentPage = 0;
            this.appliedFilters = [];
            this.selectedSort = 'relevance';
            this.selectedSeriesId = undefined;

            this.setHash();
        },
        getRecords: function() {
            let mergedFilters = JSON.parse(this.serializedFilters);
            if (this.selectedSeriesId) {
                mergedFilters = mergedFilters.concat([['series_id', this.selectedSeriesId]]);
            }

            this.$http.get('/controlled-records', {
                method: 'GET',
                params: {
                    q: this.queryString,
                    filters: JSON.stringify(mergedFilters),
                    start_date: this.startDate,
                    end_date: this.endDate,
                    page: this.currentPage,
                    page_size: AppConfig.page_size,
                    sort: this.selectedSort,
                },
            }).then((response: any) => {
                return response.json();
            }, () => {
                // Failed
                this.initialised = true;
                this.records = [];
                this.showPrevPage = false;
                this.showNextPage = false;
            }).then((json: any) => {
                this.initialised = true;

                this.showPrevPage = (this.currentPage > 0);
                this.showNextPage = json.has_next_page;

                this.records = json.results;
                this.facets = json.facets;
            });
        },
        nextPage: function() {
            this.currentPage += 1;
            this.setHash();
        },
        prevPage: function() {
            this.currentPage -= 1;
            this.setHash();
        },
        loadFilters: function(s: string) {
            try {
                this.appliedFilters = JSON.parse(s).map((parsed: string[]) => {
                    return {field: parsed[0], value: parsed[1]};
                });
            } catch (error) {
                this.appliedFilters = [];
            }
        },
    },
    updated: function() {
        if (this.$el.querySelector('.search-box') != null) {
            (this.$el.querySelector('input[name="q"]') as HTMLInputElement).value = this.queryString;
            (this.$el.querySelector('input[name="start_date"]') as HTMLInputElement).value = this.startDate;
            (this.$el.querySelector('input[name="end_date"]') as HTMLInputElement).value = this.endDate;

            this.$el.querySelectorAll('label').forEach((elt) => {
                if ((elt.control as HTMLInputElement).value) {
                  elt.classList.add('active');
                }
            });
        }
    },
    watch: {
        selectedSort: {
            handler() {
                this.setHash();
            },
        },
        selectedSeriesId: {
            handler() {
                if (this.selectedSeriesId) {
                    this.$http.get('/controlled-records', {
                        params: {
                            q: '*:*',
                            filters: JSON.stringify([["uri", this.selectedSeriesId]]),
                            page: 0,
                            page_size: 1,
                        },
                    }).then((response: any) => {
                        return response.json();
                    }, () => {
                        this.selectedSeriesLabel = this.selectedSeriesId;
                    }).then((json: any) => {
                        if (json && json.results[0]) {
                            this.selectedSeriesLabel = json.results[0].title;
                        } else {
                            this.selectedSeriesLabel = this.selectedSeriesId;
                        }
                    });
                }
            },
        },
    },
    computed: {
        browseMode: function(): boolean {
            return this.queryString === '' && this.startDate === '' && this.endDate === '';
        },
        serializedFilters: function(): string {
            return JSON.stringify(this.appliedFilters.map((filter) => [filter.field, filter.value]));
        },
    },
    mounted: function() {
        // Hash changes drive the actual search, which gives us sensible back/forward button behaviour and bookmarkability.
        this.applyHashChange();
        window.addEventListener('hashchange', () => { this.applyHashChange(); });
    },
});
