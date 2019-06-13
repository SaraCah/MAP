/// <amd-module name='controlled-records'/>


import Vue from "vue";
import VueResource from "vue-resource";
// import Utils from "./utils";

Vue.use(VueResource);

// import UI from "./ui";

interface Record {
    type: string;
    title: string;
    under_movement: boolean;
    types: string[];
    file_issue_allowed: boolean;
    id: string;
    qsa_id: number;
    physical_representations_count: number;
    digital_representations_count: number;
}

interface SearchState {
    currentPage: number;
    records: Record[];
    initialised: boolean;
    showNextPage: boolean;
    showPrevPage: boolean;
    queryString: string;
    startDate: string;
    endDate: string;
}

Vue.component('controlled-records', {
    template: `
<div>
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
            <div class="input-field">
              <label for="q">Search for keywords/identifiers</label>
              <input type="text" id="q" name="q"></input>
            </div>

            <section>
              <p>Limit to dates <span class="sample-date-formats">(YYYY, YYYY-MM, YYYY-MM-DD)</span></p>
              <div class="input-field inline">
                <label for="start_date">Start date</label>
                <input type="text" id="start_date" name="start_date"></input>
              </div>

              <div class="input-field inline">
                <label for="end_date">End date</label>
                <input type="text" id="end_date" name="end_date"></input>
              </div>
            </section>

            <button class="btn">Search</button>
            <button class="btn" v-on:click.stop.prevent="reset()">Reset</button>
          </form>
        </div>

        <template v-if="records.length === 0">
          <span class="card-title">No results found</span>
          <p>Your search did not match any results.</p>
        </template>
        <template v-else>
          <table>
            <thead>
              <tr>
                <th>Type</th>
                <th>Record</th>
                <th></th>
                <th>Agency Identifier</th>
                <th>QSA Identifier</th>
                <th>Representations</th>
                <th></th>
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
                  <a v-if="file_issues_allowed && record.file_issue_allowed"
                     class="btn"
                     :href="'/file-issue-requests/new?record_ref=' + record.id">Request</a>
                </td>
              </tr>
            </tbody>
          </table>
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
            showNextPage: false,
            showPrevPage: false,
            queryString: '',
            startDate: '',
            endDate: '',
        };
    },
    props: {
        file_issues_allowed: Boolean,
        page_size: Number,
        title: String,
    },
    methods: {
        setHash: function() {
            const key = `#q=${this.queryString}&startDate=${this.startDate}&endDate=${this.endDate}&currentPage=${this.currentPage}`;
            window.location.hash = key;
        },
        applyHashChange: function(_event: any) {
            var split = decodeURIComponent(window.location.hash).substring(1).split('&').map((s) => { return s.split("=") });
            var map: any = {};

            for (let v of split) {
                map[v[0]] = v[1];
            }

            this.queryString = map.q || '';
            this.startDate = map.startDate || '';
            this.endDate = map.endDate || '';
            this.currentPage = map.currentPage ? Number(map.currentPage) : 0;

            this.getRecords();
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

            this.setHash();
        },
        reset: function() {
            this.queryString = '';
            this.startDate = '';
            this.endDate = '';
            this.currentPage = 0;

            this.setHash();
        },
        getRecords: function() {
            this.initialised = false;

            this.$http.get('/controlled-records', {
                method: 'GET',
                params: {
                    q: this.queryString,
                    start_date: this.startDate,
                    end_date: this.endDate,
                    page: this.currentPage,
                    page_size: this.page_size + 1,
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

                this.records = json.slice(0, this.page_size);
                this.showPrevPage = (this.currentPage > 0);
                this.showNextPage = (json.length > this.page_size);
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
    },
    updated: function () {
        if (this.initialised) {
            (this.$el.querySelector('input[name="q"]') as HTMLInputElement).value = this.queryString;
            (this.$el.querySelector('input[name="start_date"]') as HTMLInputElement).value = this.startDate;
            (this.$el.querySelector('input[name="end_date"]') as HTMLInputElement).value = this.endDate;

            this.$el.querySelectorAll('label').forEach((elt) => {
                elt.classList.add('active');
            });
        }
    },
    computed: {
        browseMode: function(): boolean {
            return this.queryString === '' && this.startDate === '' && this.endDate === '';
        },
    },
    mounted: function() {
        // Hash changes drive the actual search, which gives us sensible back/forward button behaviour and bookmarkability.
        this.applyHashChange(null);
        window.addEventListener('hashchange', (event) => { this.applyHashChange(event); });
    },
});
