/// <amd-module name='file-issue-form'/>

import Vue from "vue";
import VueResource from "vue-resource";
import Utils from "./utils";

Vue.use(VueResource);

import Record from "./controlled-records";
import RepresentationRequest from "./representation-linker";

Vue.component('file-issue-form', {
    template: `
<div>
    <slot></slot>

    <template v-if="!readonly">
        <div class="row">
            <div class="col s12">
                <representation-browse v-on:selected="addRequestedItem"
                                       v-on:removed="removeRequestedItem"
                                       :selected="requestedItems"
                                       closeButtonLabel="Return to File Issue Request">
                </representation-browse>
            </div>
        </div>
    </template>

    <section id="digitalRequest" class="scrollspy section">
        <div class="card">
            <div class="card-content">
                <h4>Digital Request Summary</h4>
                <file-issue-request-summary :requested_items="requestedDigitalItems"
                                            :status="digital_request_status"
                                            :csrf_token="csrf_token"
                                            :request_id="request_id"
                                            :lock_version="lock_version"
                                            request_type="digital"
                                            :quote_blob="digital_request_quote"
                                            :file_issue_id="digital_file_issue_id"
                                            @remove="removeRequestedItem">
                </file-issue-request-summary>
            </div>
        </div>
    </section>

    <section id="physicalRequest" class="scrollspy section">
        <div class="card">
            <div class="card-content">
                <h4>Physical Request Summary</h4>
                <file-issue-request-summary :requested_items="requestedPhysicalItems"
                                            :status="physical_request_status"
                                            :csrf_token="csrf_token"
                                            :request_id="request_id"
                                            :lock_version="lock_version"
                                            request_type="physical"
                                            :quote_blob="physical_request_quote"
                                            :file_issue_id="physical_file_issue_id"
                                            @remove="removeRequestedItem">
                </file-issue-request-summary>
            </div>
        </div>
    </section>
</div>
`,
    data: function(): {requestedItems: RepresentationRequest[], readonly: boolean} {
        const items: RepresentationRequest[] = [];
        const resolved: any = JSON.parse(this.resolved_representations);

        JSON.parse(this.representations).forEach((representationBlob: any) => {
            const rep: RepresentationRequest = new RepresentationRequest(representationBlob.record_ref, '', representationBlob.request_type, representationBlob.file_issue_allowed);
            rep.recordDetails = representationBlob.record_details;
            const resolved_rep = Utils.find(resolved, (item: any) => {
                return item.ref === representationBlob.record_ref;
            });
            if (resolved_rep) {
                rep.metadata = resolved_rep;
                rep.label = rep.metadata.title;
            } else {
                rep.metadata = false;
                rep.label = "You no longer have access to this record.  Please contact QSA for more information."
            }

            items.push(rep);
        });

        return {
            requestedItems: items,
            readonly: this.is_readonly === 'true',
        };
    },
    props: ['representations',
            'resolved_representations',
            'is_readonly',
            'digital_request_status',
            'physical_request_status',
            'csrf_token',
            'request_id',
            'lock_version',
            'digital_request_quote',
            'physical_request_quote',
            'digital_file_issue_id',
            'physical_file_issue_id'],
    computed: {
        requestedDigitalItems: function(): RepresentationRequest[] {
            return Utils.filter(this.requestedItems, (item: RepresentationRequest) => {
                return item.requestType === 'DIGITAL';
            });
        },
        requestedPhysicalItems: function(): RepresentationRequest[] {
            return Utils.filter(this.requestedItems, (item: RepresentationRequest) => {
                return item.requestType === 'PHYSICAL';
            });
        },
    },
    methods: {
        addRequestedItem: function(representation: RepresentationRequest) {
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
                    this.requestedItems.push(selectedRepresentation);
                });
        },
        removeRequestedItem: function(itemToRemoveId: string) {
            this.requestedItems = Utils.filter(this.requestedItems, (item: RepresentationRequest) => {
                return item.id !== itemToRemoveId;
            });
        },
    },
});

Vue.component('file-issue-request-summary', {
    template: `
<div>
    <template v-if="requested_items.length == 0">
        <div class="row">
            <div class="col s12 m12 l6">
                <div class="card-panel blue lighten-5">No {{request_type}} items requested.</div>
            </div>
        </div>
    </template>
    <template v-else>
        <div class="row">
            <div class="col s12 right">
                <a target="_blank" href="/file-issue-fee-schedule">View Fee Schedule</a>
            </div>
        </div>

        <template v-if="status === 'QUOTE_ACCEPTED'">
            <div class="row">
                <div class="col s12 m12 l6">
                    <div class="card-panel green lighten-4">Quote Accepted! Awaiting creating of a new File Issue.</div>
                </div>
            </div>
        </template>
        <template v-if="status === 'FILE_ISSUE_CREATED'">
            <div class="row">
                <div class="col s12 m12 l6">
                    <div class="card-panel green lighten-4">
                        FI{{request_type[0].toUpperCase()}}{{file_issue_id}} created
                        <a class="btn btn-small right" :href="'/file-issues/' + file_issue_id">View</a>
                    </div>
                </div>
            </div>
        </template>
        <template v-if="status === 'CANCELLED_BY_AGENCY'">
            <div class="row">
                <div class="col s12 m12 l6">
                    <div class="card-panel red lighten-4">Request cancelled by Agency.</div>
                </div>
            </div>
        </template>
        <template v-if="status === 'CANCELLED_BY_QSA'">
            <div class="row">
                <div class="col s12 m12 l6">
                    <div class="card-panel red lighten-4">Request cancelled by QSA.</div>
                </div>
            </div>
        </template>
        <service-quote :quote_blob="quote_blob">
            <template v-if="status === 'QUOTE_PROVIDED'">
                <div class="row">
                    <div class="col s12">
                        <confirmable-action
                            :action="'/file-issue-requests/'+request_id+'/accept?request_type='+request_type+'&lock_version='+lock_version"
                            :csrf_token="csrf_token"
                            css="btn green lighten-2"
                            label="Accept Quote"
                            message="Are you sure you want to accept this quote?">
                        </confirmable-action>
                        <confirmable-action
                            :action="'/file-issue-requests/'+request_id+'/cancel?request_type='+request_type+'&lock_version='+lock_version"
                            :csrf_token="csrf_token"
                            css="btn red lighten-2"
                            label="Cancel Request"
                            message="Are you sure you want to cancel this request?">
                        </confirmable-action>
                    </div>
                </div>
            </template>
        </service-quote>

        <div class="card">
            <div class="card-content">
                <span class="card-title">Items Requested</span>
                <file-issue-requested-items-table :requested_items="requested_items"
                                       input_path="file_issue_request[items][]"
                                       @remove="removeItem">
                </file-issue-requested-items-table>
            </div>
        </div>
    </template>
</div>
`,
    props: ['requested_items',
            'status',
            'request_type',
            'request_id',
            'lock_version',
            'csrf_token',
            'quote_blob',
            'file_issue_id'],
    computed: {
        readonly: function(): boolean {
            return (this.$parent as any).readonly;
        },
    },
    methods: {
        removeItem: function(itemId: string) {
            this.$emit('remove', itemId);
        },
    },
    updated: function() {
        this.$el.querySelectorAll('input,textarea,select').forEach(function(el) {
            if ((el as HTMLFormElement).value !== "") {
                if (el.nextElementSibling) {
                    el.nextElementSibling.classList.add('active');
                }
            }
        });
    },
});


Vue.component('file-issue-requested-items-table', {
    template: `
<table class="file-issue-file-issue-requested-items-table">
    <thead>
        <tr>
            <th style="width:140px;">Issue Type</th>
            <th style="width:160px">Identifiers</th>
            <th style="min-width: 200px;">Title</th>
            <th>Dates</th>
            <th style="width:80px;">Format</th>
            <th style="min-width: 200px;">Extra Information</th>
            <th v-if="!readonly" style="width:40px;"></th>
        </tr>
    </thead>
    <tbody v-for="representation in requested_items">
        <tr v-if="!representation.metadata">
            <td>
                <input type="hidden" :name="buildPath('request_type')" v-model="representation.requestType" readonly />
                <input type="text" v-bind:value="representation.requestType === 'DIGITAL' ? 'Digitised copy' : 'Original'" readonly />
            </td>
            <td colspan="5">
                <span class="red-text">{{representation.label}}</span>
            </td>
            <td v-if="!readonly"></td>
        </tr>
        <tr v-if="representation.metadata">
            <td>
                <template v-if="readonly">
                    <input type="hidden" :name="buildPath('request_type')" v-model="representation.requestType" readonly />
                    <input type="text" v-bind:value="representation.requestType === 'DIGITAL' ? 'Digitised copy' : 'Original'" readonly />
                </template>
                <template v-else>
                    <select class="browser-default" :name="buildPath('request_type')" v-model="representation.requestType">
                        <option value="DIGITAL">Digitised copy</option>
                        <option value="PHYSICAL" v-if="isOriginalAllowed(representation)">Original</option>
                        <option value="PHYSICAL" v-else disabled="disabled">Original - The original cannot be issued due to its format or condition. Please request a digitised copy or contact QSA</option>
                    </select>
                </template>
            </td>
            <td>
                <input type="hidden" :name="buildPath('record_ref')" v-bind:value="representation.id"/>
                <input type="hidden" :name="buildPath('record_label')" v-bind:value="representation.label"/>

                <div class="identifier">Series:&nbsp;<span class="id">S{{representation.metadata.series_id}}</span></div>
                <div class="identifier">Record:&nbsp;<span class="id">R{{representation.metadata.record_id}}</span></div>

                <div class="identifier" v-if="representation.metadata.agency_assigned_id">
                    Control&nbsp;Number:&nbsp;<span class="id">{{representation.metadata.agency_assigned_id}}</span>
                </div>
                <div class="identifier" v-if="representation.metadata.previous_system_id">
                    Previous&nbsp;System:&nbsp;<span class="id">{{representation.metadata.previous_system_id}}</span>
                </div>
                <div class="identifier" v-if="representation.metadata.representation_id">
                    Representation:&nbsp;<span class="id">{{representation.qsaIdPrefix()}}{{representation.metadata.representation_id}}</span>
                </div>

            <td>{{representation.metadata.title}}</td>

            <td>{{representation.metadata.start_date}} - {{representation.metadata.end_date}}</td>

            <td>{{representation.metadata.format}}</td>

            <td>
                <section class="extra-info" v-if="representation.metadata.intended_use">
                    <label>Intended Use</label>
                    <p>{{representation.metadata.intended_use}}</p>
                </section>

                <section class="extra-info" v-if="representation.metadata.other_restrictions">
                    <label>Other Restrictions</label>
                    <p>{{representation.metadata.other_restrictions}}</p>
                </section>

                <section class="extra-info" v-if="representation.metadata.processing_handling_notes">
                    <label>Processing/Handling Notes</label>
                    <p>{{representation.metadata.processing_handling_notes}}</p>
                </section>
            </td>
            <td v-if="!readonly">
                <div class="right-align">
                    <a class="btn btn-small red darken-1" v-on:click="removeItem(representation)" title="Remove"><i class="fa fa-minus-circle" style="font-size: 1em;"></i></a>
                </div>
            </td>
        </tr>
        <tr>
            <td colspan="13">
                <div class="row">
                    <div class="col offset-s1 s10">
                        <label>Record Details</label>
                        <textarea class="materialize-textarea" :name="buildPath('record_details')" v-model="representation.recordDetails" :readonly="readonly"></textarea>
                    </div>
                </div>
            </td>
        </tr>
    </tbody>
</table>
`,
    props: ['requested_items', 'input_path'],
    computed: {
        readonly: function(): boolean {
            return (this.$parent as any).readonly;
        },
    },
    methods: {
        buildPath(field: string) {
            return this.input_path + "[" + field + "]";
        },
        removeItem: function(record: Record) {
            this.$emit('remove', record.id);
        },
        isOriginalAllowed(representation: RepresentationRequest) {
            return representation.fileIssueAllowed === 'allowed_true';
        },
    },
});
