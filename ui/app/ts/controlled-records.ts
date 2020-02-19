/// <amd-module name='controlled-records'/>


import Vue from "vue";
import VueResource from "vue-resource";
import Utils from "./utils";

Vue.use(VueResource);

declare var AppConfig: any;

export default interface Record {
    type: string;
    primary_type: string;
    title: string;
    under_movement: boolean;
    start_date: string;
    end_date: string;
    types: string[];
    file_issue_allowed: string;
    id: string;
    uri: string;
    qsa_id: number;
    qsa_id_prefixed: string;
    physical_representations_count: number;
    digital_representations_count: number;
    current_location: string|null;
    representations_json: Record[];
    nested: boolean;
    previous_system_identifiers?: string;
    top_container?: string;
    transfer_id?: string;
    rap_years?: number;
    rap_open_access_metadata?: boolean;
    rap_access_category?: boolean;
    rap_expiry_date?: string;
    rap_expired?: boolean;
    rap_expires?: boolean;
    rap_access_status?: string;
    published: boolean;
    containing_record_qsa_id_prefixed?: string;
    series?: string;
    series_qsa_id_prefixed?: string;
    series_qsa_id?: string;
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

interface Clause {
    op: string;
    field: string;
    query: string;
}

interface SearchState {
    currentPage: number;
    facets: object;
    records: Record[];
    initialised: boolean;
    searchActive: boolean;
    showNextPage: boolean;
    showPrevPage: boolean;
    lastSearchedQueryClauses: Clause[];
    queryClauses: Clause[];
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
                                <blockquote>Searching within series: {{selectedSeriesLabel}} [<a href="javascript:void(0);" @click="reset({clearSeries: true})">reset</a>]</blockquote>
                            </div>
                        </section>

                        <section class="row" v-for="(clause, idx) in this.queryClauses">
                            <div class="col s2">
                                <div class="input-field" v-if="idx > 0">
                                    <select v-model="clause.op" class="browser-default">
                                        <option value="AND">AND</option>
                                        <option value="OR">OR</option>
                                        <option value="NOT">NOT</option>
                                    </select>
                                </div>
                            </div>

                            <div class="col s5">
                                <div class="input-field">
                                    <label :for="'q_' + idx">Search for</label>
                                    <input :id="'q_' + idx" type="text" v-model="clause.query"></input>
                                </div>
                            </div>

                            <div class="col s3">
                                <div class="input-field">
                                    <select v-model="clause.field" class="browser-default">
                                        <option value="keywords">All fields</option>
                                        <option value="qsa_id">QSA ID</option>
                                        <option value="agency_id">Agency ID</option>
                                        <option value="title">Title</option>
                                        <option value="transfer_id">Transfer ID</option>
                                        <option value="series_number">Series Number</option>
                                        <option value="box_number">Box Number</option>
                                        <option value="previous_id">Previous System ID</option>
                                    </select>
                                </div>
                            </div>

                            <div class="col s2">
                                <div class="input-field">
                                    <button type="button" style="width: 4em;" class="btn" v-on:click.stop.prevent="addClause()">+</button>
                                    <button type="button" style="width: 4em;" class="btn" v-on:click.stop.prevent="removeClause(idx)">&mdash;</button>
                                </div>
                            </div>
                        </section>

                        <section class="row">
                            <div class="col s12">
                                <div class="input-field inline date-limit">Limit to dates</div>
                                <div class="input-field inline">
                                    <label for="start_date">Start date</label>
                                    <input type="text" size="10" id="start_date" name="start_date"></input>
                                    <span class="helper-text">YYYY-MM-DD</span>
                                </div>
                                <div class="input-field inline date-to">
                                    to
                                </div>
                                <div class="input-field inline">
                                    <label for="end_date">End date</label>
                                    <input type="text" size="10" id="end_date" name="end_date"></input>
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

                            <div class="row">
                                <template v-for="filter in this.availableFilters">
                                    <div class="col s4 m4 l12 facet-section" v-if="facets[filter.field] && facets[filter.field].length > 0">
                                        <span class="facet-title">{{filter.title}}</span>
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
                                    </div>
                                </template>
                            </div>

                        </div>
                        <div class="col s12 m12 l9 search-results">
                            <table class="highlight">
                                <thead>
                                    <tr>
                                        <th>Type</th>
                                        <th>Title</th>
                                        <th></th>
                                        <th>Identifiers</th>
                                        <th>Representations</th>
                                        <th>Dates</th>
                                        <th>Series</th>
                                        <th>RAP Info</th>
                                        <th style="width: 18em"></th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <template v-for="record in flattenRecords(records)">
                                        <tr v-bind:class="{ nested: record.nested, top: !record.nested }" v-show="!record.nested" :key="record.id + record.nested">
                                            <td><div class="indent-wrapper">{{record.type}}</div></td>
                                            <td>
                                                {{record.title}}
                                                <div v-if="record.description" class="record-description-container">
                                                    <div><small><a href="javascript:void(0);" @click.stop.prevent="toggleDescription($event)">Toggle Description</a></small></div>
                                                    <div class="record-description" style="display: none;">
                                                        {{record.description}}
                                                    </div>
                                                </div>
                                            </td>
                                            <td><span class="badge" v-if="record.under_movement">under movement</span></td>
                                            <td>
                                                <div v-if="record.qsa_id_prefixed" class="inline-label-value-row">
                                                    <span class="inline-label">QSA ID:</span> <span class="inline-value">{{record.qsa_id_prefixed}}</span></div>
                                                <div v-if="record.agency_assigned_id" class="inline-label-value-row">
                                                    <span class="inline-label">Agency ID:</span> <span class="inline-value">{{record.agency_assigned_id}}</span>
                                                </div>
                                                <div v-if="record.previous_system_identifiers" class="inline-label-value-row">
                                                    <span class="inline-label">Previous System ID:</span> <span class="inline-value">{{record.previous_system_identifiers}}</span>
                                                </div>
                                                <div v-if="record.top_container" class="inline-label-value-row">
                                                    <span class="inline-label">Container ID:</span> <span class="inline-value">{{record.top_container}}</span>
                                                </div>
                                                <div v-if="record.transfer_id" class="inline-label-value-row">
                                                    <span class="inline-label">Transfer ID:</span> <span class="inline-value">{{record.transfer_id}}</span>
                                                </div>
                                            </td>
                                            <td>
                                                <span v-if="record.primary_type === 'resource' || ((record.physical_representations_count === 0) && (record.digital_representations_count === 0))">
                                                    {{record.physical_representations_count}} physical<br>{{record.digital_representations_count}} digital
                                                </span>
                                                <span v-else-if="record.primary_type === 'archival_object'">
                                                    <a href="javascript:void(0);" @click.stop.prevent="toggleRepresentations($event)">{{record.physical_representations_count}} physical<br>{{record.digital_representations_count}} digital</a>
                                                </span>

                                            </td>
                                            <td>{{ buildDates(record) }}</td>
                                            <td><span v-if="!record.nested">
                                                {{record.series_qsa_id_prefixed}} {{record.series}}</span>
                                            </td>
                                            <td>
                                                <div v-if="record.rap_years" class="inline-label-value-row">
                                                    <span class="inline-label">Years:</span> <span class="inline-value">{{record.rap_years}}</span>
                                                </div>
                                                <div v-if="record.rap_expires" class="inline-label-value-row">
                                                    <span class="inline-label" v-if="record.rap_expired">Expired:</span>
                                                    <span class="inline-label" v-else="record.rap_expired">Expires:</span> <span class="inline-value">{{record.rap_expiry_date}}</span>
                                                </div>
                                                <div v-if="record.rap_expires === false" class="inline-label-value-row">
                                                    <span class="inline-label">Expires:</span> <span class="inline-value">No expiry</span>
                                                </div>
                                                <div v-if="record.rap_open_access_metadata != null" class="inline-label-value-row">
                                                    <span class="inline-label">Metadata Published?:</span> <span class="inline-value"><span v-if="record.rap_open_access_metadata">Yes</span><span v-else>No</span></span>
                                                </div>
                                            </td>
                                            <td>
                                                <a :href="urlForPublicRecord(record)" v-if="record.published" target="_blank">
                                                    View on ArchivesSearch
                                                </a>
                                                <a href="javascript:void(0);" @click="searchWithinSeries(record)" v-if="record.primary_type === 'resource' && !selectedSeriesId">Search&nbsp;within&nbsp;series</a>
                                                <slot name="record_actions" v-bind:record="record"></slot>
                                            </td>
                                        </tr>
                                    </template>
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
            searchActive: false,
            currentPage: 0,
            records: [],
            facets: [],
            showNextPage: false,
            showPrevPage: false,

            // The query that we last fired.  If the user adds filters, moves
            // between pages, changes sorting, those actions are performed against
            // this base query, not the contents of the search form on the page
            // (which might have been changed).
            lastSearchedQueryClauses: [],

            // The query that exists in the search form (which may not have been
            // submitted yet).  This becomes `lastSearchedQueryClauses` when the
            // user fires the search.
            queryClauses: [],

            startDate: '',
            endDate: '',
            availableFilters: [{field: 'primary_type', title: 'Record Types'},
                               {field: 'series', title: 'Series'},
                               {field: 'creating_agency', title: 'Creating Agency'},
                               {field: 'rap_access_status', title: 'Access Status'},
                               {field: 'format', title: 'Format'},
                               {field: 'subjects', title: 'Subject'},
                              ],
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
                ['q', this.queryClauses],
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

            this.queryClauses = map.q || [];
            this.lastSearchedQueryClauses = JSON.parse(JSON.stringify(this.queryClauses));
            this.startDate = map.startDate || '';
            this.endDate = map.endDate || '';
            this.currentPage = map.currentPage ? Number(map.currentPage) : 0;
            this.selectedSort = map.sort || 'relevance';
            this.selectedSeriesId = map.series || undefined;

            this.loadFilters(map.appliedFilters || '[]');

            this.getRecords();
        },
        searchWithinSeries: function(record: Record) {
            this.reset({
                setHash: false,
            });
            this.selectedSeriesId = record.uri;
            this.setHash();
        },
        toggleRepresentations: function(event: any) {
            const topRow = event.target.closest('tr');
            const showChildren = topRow.classList.toggle('expanded');

            let row = topRow;
            while ((row = row.nextSibling) != null && row.classList.contains('nested')) {
                row.style.display = (showChildren ? 'table-row' : 'none');
            }
        },
        toggleDescription: function(event: any) {
          const container = event.target.closest('.record-description-container');
          const description = container.querySelector('.record-description');
          description.style.display = (description.style.display === 'block' ? 'none' : 'block');
        },
        urlForPublicRecord: function(record: Record) {
            let url = AppConfig.public_url || 'http://foo.com';
            if (record.primary_type === 'resource') {
                url += "/series/" + record.qsa_id_prefixed;
            } else if (record.primary_type === 'archival_object') {
                url += "/items/" + record.qsa_id_prefixed;
            } else if (record.primary_type === 'physical_representation') {
                url += "/items/" + record.containing_record_qsa_id_prefixed;
            } else if (record.primary_type === 'digital_representation') {
                url += "/items/" + record.containing_record_qsa_id_prefixed;
            }
            return url;
        },
        buildDates: function(record: Record) {
            if (record.type.indexOf("Representation") >= 0) {
                // These don't have dates of their own
                return "";
            }

            const startYear = record.start_date.substring(0, 4);
            let endYear = record.end_date.substring(0, 4);

            if (endYear === '9999') {
                endYear = 'present';
            } else if (endYear === startYear) {
                return startYear;
            }

            return [startYear, endYear].join(' - ');
        },
        addClause: function() {
            this.queryClauses.push({
                op: 'AND',
                field: 'keywords',
                query: '',
            });
        },
        removeClause: function(idx: number) {
            this.queryClauses = this.queryClauses.slice(0, idx).concat(this.queryClauses.slice(idx + 1));
        },

        addFilter: function(facet: Facet) {
            this.appliedFilters.push(facet);
            this.currentPage = 0;
            this.setHash();
        },
        removeFilter: function(facet: Facet) {
            this.appliedFilters = Utils.filter(this.appliedFilters,
                                               (elt: Filter) => !((elt.field === facet.field) && (elt.value === facet.value)));
            this.currentPage = 0;
            this.setHash();
        },
        isFilterApplied: function(facet: Facet): boolean {
            return !!Utils.find(this.appliedFilters,
                                (elt: Filter) => (elt.field === facet.field) && (elt.value === facet.value));
        },
        search: function() {
            this.startDate = (this.$el.querySelector('input[name="start_date"]') as HTMLInputElement).value;
            this.endDate = (this.$el.querySelector('input[name="end_date"]') as HTMLInputElement).value;

            this.appliedFilters = [];
            this.currentPage = 0;
            this.selectedSort = 'relevance';

            this.setHash();
        },
        reset: function(opts?: any) {
            opts = opts ? opts : {};

            this.queryClauses = [];
            this.lastSearchedQueryClauses = [];
            this.startDate = '';
            this.endDate = '';
            this.currentPage = 0;
            this.appliedFilters = [];
            this.selectedSort = 'relevance';

            if (opts.clearSeries) {
                this.selectedSeriesId = undefined;
            }

            if (opts.setHash !== false) {
                this.setHash();
            }
        },
        focusSearchBox: function() {
            this.$nextTick(() => {
                const inputElt = this.$el.querySelector('input[name="q"]');
                if (inputElt) {
                    (inputElt as HTMLInputElement).focus();
                }
            });
        },
        getRecords: function() {
            let mergedFilters = JSON.parse(this.serializedFilters);
            if (this.selectedSeriesId) {
                mergedFilters = mergedFilters.concat([['series_id', this.selectedSeriesId]]);
            }

            this.searchActive = true;

            this.$http.get('/controlled-records', {
                method: 'GET',
                params: {
                    q: JSON.stringify(this.queryClauses),
                    filters: JSON.stringify(mergedFilters),
                    start_date: this.startDate,
                    end_date: this.endDate,
                    page: this.currentPage,
                    page_size: AppConfig.page_size,
                    sort: this.selectedSort,
                },
            }).then((response: any) => {
                this.searchActive = false;
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
        flattenRecords: function(records: Record[]) {
            const result = []

            for (const record of records) {
                result.push(record);

                if (record.representations_json) {
                    for (let representation of record.representations_json) {
                        representation.nested = true;
                        result.push(representation);
                    }
                }
            }

            return result;
        },
        nextPage: function() {
            if (!this.searchActive) {
                this.currentPage += 1;
                this.setHash();
            }
        },
        prevPage: function() {
            if (!this.searchActive) {
                this.currentPage -= 1;

                if (this.currentPage < 0) {
                    this.currentPage = 0;
                }

                this.setHash();
            }
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
        if (this.queryClauses.length === 0) {
            this.addClause();
        }

        if (this.$el.querySelector('.search-box') != null) {
            (this.$el.querySelector('input[name="start_date"]') as HTMLInputElement).value = this.startDate;
            (this.$el.querySelector('input[name="end_date"]') as HTMLInputElement).value = this.endDate;

            this.$el.querySelectorAll('label').forEach((elt) => {
                const targetId: string|null = elt.getAttribute('for');
                if (targetId) {
                    const input: Element|null = document.getElementById(targetId);
                    if (input) {
                        if ((input as HTMLInputElement).value) {
                            elt.classList.add('active');
                        }
                    }
                }
            });
        }
    },
    watch: {
        initialised: function(newValue, oldValue) {
            if (!oldValue && newValue) {
                this.focusSearchBox();
            }
        },
        selectedSort: {
            handler() {
                this.currentPage = 0;
                this.setHash();
            },
        },
        selectedSeriesId: {
            handler() {
                if (this.selectedSeriesId) {
                    this.$http.get('/controlled-records', {
                        params: {
                            q: '[]',
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
            const emptyQuery = (this.lastSearchedQueryClauses.map((c) => c.query.length).reduce((t, n) => t + n, 0) === 0);

            return emptyQuery && this.startDate === '' && this.endDate === '' && !this.searchActive;
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
