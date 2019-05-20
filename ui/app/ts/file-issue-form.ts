/// <amd-module name='file-issue-form'/>


import Vue from "vue";
import VueResource from "vue-resource";
import Utils from "./utils";
// import Utils from "./utils";
// import UI from "./ui";
Vue.use(VueResource);
// import Utils from "./utils";
import RepresentationRequest from "./representation-linker";

Vue.component('file-issue-form', {
    template: `
<div>
    <section id="items" class="scrollspy section card">
        <div class="card-content">
            <representation-linker input_path="file_issue_request[items][]" ref="linker" :representations="representations" :resolved_representations="resolved_representations" @change="refreshSummaries()" :readonly="readonly"></representation-linker>
        </div>
    </section>

    <slot></slot>

    <section id="digitalRequest" class="scrollspy section">
        <h4>Digital Request Summary</h4>
        <file-issue-digital-request ref="digitalRequest"></file-issue-digital-request>
    </section>

    <section id="physicalRequest" class="scrollspy section">
        <h4>Physical Request Summary</h4>
        <file-issue-physical-request ref="physicalRequest"></file-issue-physical-request>
    </section>
</div>
`,
    data: function(): {readonly: boolean} {
        return {
            readonly: this.is_readonly == 'true',
        };
    },
    props: ['representations', 'resolved_representations', 'is_readonly'],
    methods: {
        refreshSummaries: function() {
            // FIXME type?
            const digitalRequest:any = this.$refs.digitalRequest;
            digitalRequest.syncItems(this.getDigitalRepresentations());
            const physicalRequest:any = this.$refs.physicalRequest;
            physicalRequest.syncItems(this.getPhysicalRepresentations());
        },
        getDigitalRepresentations: function() {
            // FIXME type? 
            const linker:any = this.$refs.linker;
            return Utils.filter(linker.getSelected(), (rep:RepresentationRequest) => {
                return rep.request_type == 'DIGITAL';
            });
        },
        getPhysicalRepresentations: function() {
            // FIXME type? 
            const linker:any = this.$refs.linker;
            return Utils.filter(linker.getSelected(), (rep:RepresentationRequest) => {
                return rep.request_type == 'PHYSICAL';
            });
        },
    },
    mounted: function() {
        console.log("MOUNTED: file-issue-form");
        this.refreshSummaries();
    }
});

Vue.component('file-issue-physical-request', {
    template: `
<div>
    <template v-if="items.length == 0">
        No physical items requested
    </template>
    <template v-else>
        <table>
            <thead>
                <tr>
                    <th style="width: 60px;">Series ID</th>
                    <th style="width: 60px;">Record ID</th>
                    <th>Title</th>
                    <th>Record Details</th>
                    <th style="width: 60px;">Representation ID</th>
                    <th style="width: 100px;">Format</th>
                    <!-- <th>Processing/ Handling Notes</th> -->
                </tr>
            </thead>
            <tbody>
                <tr v-for="representation in items">
                    <td>{{representation.metadata.series_id}}</td>
                    <td>{{representation.metadata.record_id}}</td>
                    <td>{{representation.metadata.title}}</td>
                    <td>{{representation.record_details}}</td>
                    <td>{{representation.metadata.representation_id}}</td>
                    <td>{{representation.metadata.format}}</td>
                </tr>
            </tbody>
        </table>
    </template>
</div>
`,
    data: function(): {items: RepresentationRequest[]} {
        return {
            items: [],
        };
    },
    methods: {
        syncItems: function(reps:RepresentationRequest[]) {
            this.items = reps;
        }
    },
    mounted: function() {
        console.log("MOUNTED: file-issue-physical-request");
    }
});

Vue.component('file-issue-digital-request', {
    template: `
<div>
    <template v-if="items.length == 0">
        No digital items requested
    </template>
    <template v-else>
        <table>
            <thead>
                <tr>
                    <th style="width: 60px;">Series ID</th>
                    <th style="width: 60px;">Record ID</th>
                    <th>Title</th>
                    <th>Record Details</th>
                    <th style="width: 60px;">Representation ID</th>
                    <th style="width: 100px;">Format</th>
                    <!-- <th>Processing/ Handling Notes</th> -->
                </tr>
            </thead>
            <tbody>
                <tr v-for="representation in items">
                    <td>{{representation.metadata.series_id}}</td>
                    <td>{{representation.metadata.record_id}}</td>
                    <td>{{representation.metadata.title}}</td>
                    <td>{{representation.record_details}}</td>
                    <td>{{representation.metadata.representation_id}}</td>
                    <td>{{representation.metadata.format}}</td>
                </tr>
            </tbody>
        </table>
    </template>
</div>
`,
    data: function(): {items:RepresentationRequest[]} {
        return {
            items: [],
        };
    },
    methods: {
        syncItems: function(reps:RepresentationRequest[]) {
            this.items = reps;
        }
    },
    mounted: function() {
        console.log("MOUNTED: file-issue-digital-request");
    }
});
