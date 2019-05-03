/// <amd-module name='file-uploader'/>


import Vue from "vue";
import VueResource from "vue-resource";
import Utils from "./utils";

Vue.use(VueResource);

interface UploadedFile {
    key:String;
    filename:String;
    role?:String;
    created_by?:String;
    create_time?:String;
}

interface UploaderState {
    uploaded:UploadedFile[];
    is_readonly:Boolean;
    is_role_enabled:Boolean;
}

Vue.component('file-uploader', {
    template: `
<div>
    <template v-if="!is_readonly">
        <div class="file-field input-field">
            <div class="btn">
                <span>Upload File(s)</span>
                <input type="file" ref="upload" multiple v-on:change="uploadFiles">
            </div>
            <div class="file-path-wrapper">
                <input class="file-path" type="text">
            </div>
        </div>
    </template>
    <template v-if="uploaded.length > 0">
        <div class="card">
            <div class="card-content">
                <table>
                    <thead>
                        <tr>
                            <th style="width: 40%">Filename</th>
                            <template v-if="is_role_enabled">
                                <th>Role</th>
                            </template>
                            <th>Created by</th>
                            <th>Create Time</th>
                            <th></th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr v-for="file in uploaded">
                            <td>
                                {{file.filename}}
                                <input type="hidden" v-bind:name="buildPath('key')" v-bind:value="file.key"/>
                                <input type="hidden" v-bind:name="buildPath('filename')" v-bind:value="file.filename"/>
                            </td>
                            <template v-if="is_role_enabled">
                                <td>
                                    <select :name="buildPath('role')" v-model="file.role" class="browser-default">
                                        <option value="CSV">CSV</option>
                                        <option value="RAP">RAP Notice</option>
                                        <option value="OTHER">Other</option>
                                    </select>
                                </td>
                            </template>
                            <td>{{file.created_by}}</td>
                            <td>{{formatTime(file.create_time)}}</td>
                            <td>
                                <a class="btn" target="_blank" :href="'/file-download?key=' + file.key + '&filename=' + file.filename">Download</a>
                                <template v-if="!is_readonly">
                                    <a class="btn" v-on:click="remove(file)">Remove</a>
                                </template>
                            </td>
                        </tr>
                    </tbody>
                </table>
            </div>
        </div>
    </template>
</div>
`,
    data: function(): UploaderState {
        return {
            uploaded: JSON.parse(this.files),
            is_readonly: (this.readonly == 'true'),
            is_role_enabled: (this.role == 'enabled'),
        };
    },
    props: ['files', 'csrf_token', 'input_path', 'readonly', 'role'],
    methods: {
        uploadFiles: function() {
            let uploadInput = <HTMLInputElement>this.$refs.upload;
            let files:FileList|null = uploadInput.files;

            if (files && files.length > 0) {
                let formData = new FormData();
                for (let i = 0; i < files.length; i++) {
                    let file:File|null = files.item(i);
                    if (file) {
                        formData.append('file[]', file);
                    }
                }
                formData.append('authenticity_token', this.csrf_token);
                this.$http.post('/file-upload', formData, {
                    headers: {
                        'Content-Type': 'multipart/form-data'
                    },
                    // emulateJSON: true,
                }).then((response: any) => {
                    return response.json();
                }, () => {
                }).then((json:UploadedFile[]) => {
                    for (let uploadedFile of json) {
                        if (uploadedFile.role == null) {
                            if (uploadedFile.filename.slice(-3) == 'csv') {
                                uploadedFile.role = 'CSV';
                            } else {
                                uploadedFile.role = 'OTHER';
                            }
                        }
                        this.uploaded.push(uploadedFile);
                    }
                });
            }
        },
        remove(fileToRemove: UploadedFile) {
            this.uploaded = Utils.filter(this.uploaded, (file: UploadedFile) => {
                return fileToRemove.key !== file.key;
            });
        },
        buildPath(field:String) {
            return this.input_path + "[" + field + "]";
        },
        formatTime: function(epochTime:number|null) {
            if (epochTime) {
                return Utils.localDateForEpoch(epochTime);
            } else {
                return '';
            }
        },
    }
});
