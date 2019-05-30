/// <amd-module name='controlled-records'/>


import Vue from "vue";
import VueResource from "vue-resource";
// import Utils from "./utils";

Vue.use(VueResource);

// import UI from "./ui";

interface Record {
    type: string,
    title: string,
    under_movement: boolean,
    types: string[],
    file_issue_allowed: boolean,
    id: string,
    qsa_id: number,
    physical_representations_count: number,
    digital_representations_count: number,
}

Vue.component('controlled-records', {
    template: `
<div>
  <div class="card" v-if="!initialised">
  </div>
  <div class="card" v-else-if="records.length == 0">
    <div class="card-content">
      <span class="card-title">No controlled records</span>
      <p>Your agency does not currently control any records.</p>
    </div>
  </div>
  <div class="card" v-else>
    <div class="card-content">
      <div class="row">
        <span class="card-title">{{title}}</span>
        <table>
          <thead>
            <tr>
              <th>Type</th>
              <th>Record</th>
              <th></th>
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
      </div>
      <div class="row">
        <div class="col s12 center-align">
          <a :style="showPrevPage ? 'visibility: visible' : 'visibility: hidden'" href="javascript:void(0)" v-on:click.stop.prevent="currentPage -= 1"><i class="fa fa-chevron-left"></i> Previous</a>
          <a :style="showNextPage ? 'visibility: visible' : 'visibility: hidden'" href="javascript:void(0)" v-on:click.stop.prevent="currentPage += 1">Next <i class="fa fa-chevron-right"></i></a>
        </div>
      </div>
    </div>
  </div>
</div>
`,
    data: function(): {
        currentPage: number,
        records: Record[],
        initialised: boolean,
        pageSize: number,
        showNextPage: boolean,
        showPrevPage: boolean,
    } {
        return {
            pageSize: 5,
            initialised: false,
            currentPage: 0,
            records: [],
            showNextPage: false,
            showPrevPage: false,
        };
    },
    props: {
        file_issues_allowed: Boolean,
        title: String,
    },
    methods: {
        getRecords: function() {
            this.$http.get('/controlled-records', {
                method: 'GET',
                params: {
                    page: this.currentPage,
                    page_size: this.pageSize + 1,
                }
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

                this.records = json.slice(0, this.pageSize);
                this.showPrevPage = (this.currentPage > 0);
                this.showNextPage = (json.length > this.pageSize);
            });
        },
    },
    watch: {
        currentPage: function () {
            this.getRecords();
        },
    },
    mounted: function() {
        this.getRecords();
    },
});
