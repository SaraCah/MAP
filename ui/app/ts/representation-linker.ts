/// <amd-module name='representation-linker'/>


import Vue from "vue";
import VueResource from "vue-resource";
import Utils from "./utils";
// import Utils from "./utils";
// import UI from "./ui";
Vue.use(VueResource);
// import Utils from "./utils";
// import UI from "./ui";

interface Representation {
    id: string;
    label: string;
}

export default class RepresentationRequest {
    public static fromRepresentation(rep: Representation): RepresentationRequest {
        return new RepresentationRequest(rep.id, rep.label, 'DIGITAL');
    }

    public recordDetails: string;
    public metadata: any;

    constructor(public id: string,
                public label: string,
                public requestType: string) {
        this.recordDetails = '';
    }
}

Vue.component('representation-typeahead', {
    template: `
<div>
  <input id="representation-typeahead" v-on:keyup="handleInput" type="text" v-model="text" ref="text" placeholder="Search for records..."/>
  <ul>
    <li v-for="representation in matches">
      <a href="javascript:void(0);" v-on:click="select(representation)">{{ representation.label }}</a>
    </li>
  </ul>
</div>
`,
    data: function(): {matches: Representation[], text: string, handleInputTimeout: number|null} {
        return {
            matches: [],
            text: '',
            handleInputTimeout: null,
        };
    },
    methods: {
        handleInput() {
            if (this.text.length > 0) {
                if (this.handleInputTimeout != null) {
                    clearTimeout(this.handleInputTimeout);
                }
                this.handleInputTimeout = setTimeout(() => {
                    this.$http.get('/search/representations', {
                        method: 'GET',
                        params: {
                            q: this.text,
                        },
                    }).then((response: any) => {
                        return response.json();
                    }, () => {
                        this.matches = [];
                    }).then((json: any) => {
                        this.matches = json;
                    });
                }, 300);
            }
        },
        select(representation: Representation) {
            this.$emit('selected', representation);
            this.matches = [];
            this.text = '';
            (this.$refs.text as HTMLElement).focus();
        },
    },
});

Vue.component('representation-linker', {
    template: `
<div>
    <template v-if="!readonly">
        <representation-typeahead v-on:selected="addSelected"></representation-typeahead>
    </template>
    <table class="representation-linker-table">
        <thead>
            <tr>
                <th>Identifiers</th>
                <th>Title</th>
                <th>Start Date</th>
                <th>End Date</th>
                <th>Format</th>
                <th>File Issue Allowed</th>
                <th>Extra Information</th>
            </tr>
        </thead>
        <tbody v-for="representation in selected">
            <tr>
                <td>
                  <input type="hidden" :name="buildPath('record_ref')" v-bind:value="representation.id"/>
                  <input type="hidden" :name="buildPath('record_label')" v-bind:value="representation.label"/>

                  <div class="identifier">Series:&nbsp;<span class="id">{{representation.metadata.series_id}}</span></div>
                  <div class="identifier">Record:&nbsp;<span class="id">{{representation.metadata.record_id}}</span></div>

                  <div class="identifier" v-if="representation.metadata.agency_assigned_id">
                    Control&nbsp;Number:&nbsp;<span class="id">{{representation.metadata.agency_assigned_id}}</span>
                  </div>
                  <div class="identifier" v-if="representation.metadata.previous_system_id">
                    Previous&nbsp;System:&nbsp;<span class="id">{{representation.metadata.previous_system_id}}</span>
                  </div>
                  <div class="identifier" v-if="representation.metadata.representation_id">
                    Representation:&nbsp;<span class="id">{{representation.metadata.representation_id}}</span>
                  </div>

                <td>{{representation.metadata.title}}</td>

                <td>{{representation.metadata.start_date}}</td>
                <td>{{representation.metadata.end_date}}</td>

                <td>{{representation.metadata.format}}</td>
                <td>
                  <span v-if="representation.metadata.file_issue_allowed">yes</span>
                  <span v-else>no</span>
                </td>

                <td>
                  <section class="extra-info" v-if="representation.metadata.intended_use">
                    <h2>Intended Use</h2>
                    <p>{{representation.metadata.intended_use}}</p>
                  </section>

                  <section class="extra-info" v-if="representation.metadata.other_restrictions">
                    <h2>Other Restrictions</h2>
                    <p>{{representation.metadata.other_restrictions}}</p>
                  </section>

                  <section class="extra-info" v-if="representation.metadata.processing_handling_notes">
                    <h2>Processing/Handling Notes</h2>
                    <p>{{representation.metadata.processing_handling_notes}}</p>
                  </section>
                </td>
            </tr>
            <tr>
                <td colspan="13">
                    <div class="row">
                        <div class="col s2">
                            <label>Request Type</label>
                            <template v-if="readonly">
                                <input type="text" :name="buildPath('request_type')" v-model="representation.requestType" readonly />
                            </template>
                            <template v-else>
                                <select class="browser-default" :name="buildPath('request_type')" v-model="representation.requestType" v-on:change="handleRequestTypeChange()">
                                    <option value="DIGITAL">Digital</option>
                                    <option value="PHYSICAL">Physical</option>
                                </select>
                            </template>
                        </div>
                        <div class="col s8">
                            <label>Record Details</label>
                            <textarea class="materialize-textarea" :name="buildPath('record_details')" v-model="representation.recordDetails" :readonly="readonly"></textarea>
                        </div>
                        <div class="col s2">
                            <template v-if="!readonly">
                                <div class="right-align">
                                    <a class="btn" v-on:click="removeSelected(representation)">Remove</a>
                                </div>
                            </template>
                        </div>
                    </div>
                </td>
            </tr>
        </tbody>
  </table>
</div>
`,
    data: function(): {selected: RepresentationRequest[]} {
        const prepopulated: RepresentationRequest[] = [];

        const resolved: any = JSON.parse(this.resolved_representations);

        JSON.parse(this.representations).forEach((representationBlob: any) => {
            const rep: RepresentationRequest = new RepresentationRequest(representationBlob.record_ref, '', representationBlob.request_type);
            rep.recordDetails = representationBlob.recordDetails;
            rep.metadata = Utils.find(resolved, (item: any) => {
                return item.ref === representationBlob.record_ref;
            });
            rep.label = rep.metadata.title;
            prepopulated.push(rep);
        });

        return {
            selected: prepopulated,
        };
    },
    props: ['input_path', 'representations', 'resolved_representations', 'readonly'],
    methods: {
        getSelected: function() {
            return this.selected;
        },
        addSelected: function(representation: RepresentationRequest) {
            const selectedRepresentation: RepresentationRequest = RepresentationRequest.fromRepresentation(representation);
            this.$http.get('/resolve/representations', {
                method: 'GET',
                params: {
                    'ref[]': selectedRepresentation.id,
                },
            }).then((response: any) => response.json())
              .then((json: any) => {
                  selectedRepresentation.metadata = json[0];
                  selectedRepresentation.label = selectedRepresentation.metadata.title;
                  this.selected.push(selectedRepresentation);
                  this.$emit('change');
              });
        },
        removeSelected: function(representationToRemove: RepresentationRequest) {
            this.selected = Utils.filter(this.selected, (representation: RepresentationRequest) => {
                return !(representation.id === representationToRemove.id && representation.requestType === representationToRemove.requestType);
            });
            this.$emit('change');
        },
        handleRequestTypeChange: function() {
            this.$emit('change');
        },
        buildPath(field: string) {
            return this.input_path + "[" + field + "]";
        },
    },
});
