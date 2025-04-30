public class ContentPuller {
    public class Input {
        @InvocableVariable(required=true)
        public string fileId;
    }
    
    public class Output {
        @InvocableVariable
        public String fileContent;
    }
    
    @InvocableMethod(label='File Content Reader')
    public static List<Output> pullContent(List<Input> inputs) {
        List<Output> outputResults = new List<Output>();
        outputResults = returnOutputResults('No content found or something wrong.');
        try {
            if(inputs.size() > 0) {
                Input userInput = inputs[0]; 
                String sObjName = ((Id)userInput.fileId).getSObjectType().getDescribe().getName();
                String fileId;
                if(sObjName != 'ContentVersion' || sObjName != 'ContentDocument' ){
                    ContentDocumentLink[] cdls = [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId =:userInput.fileId];
                    if(cdls != null && !cdls.isEmpty()){
                        fileId = cdls[0].ContentDocumentId;
                    }
                } 
                
                
                List<ContentVersion> cvList = [
                    SELECT Id, VersionData
                    FROM ContentVersion
                    WHERE FileType = 'PDF' AND (ContentDocumentId = :fileId OR Id =:fileId)
                    ORDER BY LastModifiedDate DESC
                    LIMIT 1
                ]; 
                
                if(cvList.size() > 0) {
                    Blob versionData = cvList[0].VersionData;
                    string base64Value = EncodingUtil.base64Encode(versionData);
                    
                    RequestWrapper reqWrapper = new RequestWrapper();
                    reqWrapper.Parameters = new List<Parameters>();
                    Parameters pInput = new Parameters();
                    pInput.Name = 'File';
                    pInput.FileValue = new FileValue();
                    pInput.FileValue.Name = 'agentforce-test-input-file.pdf';
                    pInput.FileValue.Data = base64Value;
                    reqWrapper.Parameters.add(pInput);
                    
                    Parameters pOutput = new Parameters();
                    pOutput.Name = 'FileName';
                    pOutput.Value = 'agentforce-test-output-file';
                    reqWrapper.Parameters.add(pOutput);
                    
                    Http http = new Http();
                    HttpRequest request = new HttpRequest();
                    request.setEndpoint('https://v2.convertapi.com/convert/pdf/to/txt');
                    request.setMethod('POST');
                    System.debug('====Req Body====' + JSON.serialize(reqWrapper));
                    String authorizationHeader = 'Bearer secret_OWPkf9Pz0T6ZaoR9';
                    request.setHeader('Authorization', authorizationHeader);
                    request.setHeader('Accept', '*/*');
                    request.setBody(JSON.serialize(reqWrapper));
                    request.setHeader('Content-Type','application/json');
                    request.setTimeout(120000);
                    
                    HttpResponse response = http.send(request);
                    System.debug('=====response===' + response);
                    string strBody = '';
                    if(response.getStatusCode() == 200 && String.isNotBlank(response.getBody())) {
                        strBody = response.getBody();
                        System.debug('=====strBody===' + strBody);
                        ResponseWrapper rw = (ResponseWrapper)JSON.deserialize(strBody, ResponseWrapper.Class);
                        
                        Blob b = EncodingUtil.base64Decode(rw.Files[0].FileData);
                        string textData = b.toString();
                        System.debug('===textData====' + textData);
                        outputResults = returnOutputResults(textData);
                    } else {
                        outputResults = returnOutputResults('Error code is ' + response.getStatusCode() + ' and Error Body is ' + response.getBody());
                    }
                } else {
                    outputResults = returnOutputResults('File not found in the System.');
                }
            } else {
                outputResults = returnOutputResults('No file id input found to search the content.');
            }
        } catch(Exception ex) {
            return returnOutputResults('Exception: ' + ex.getMessage() + ' at line ===' + ex.getLineNumber());
        }
        return outputResults;
    }
    
    private static List<Output> returnOutputResults(string strFileContent) {
        List<Output> outputResults = new List<Output>();
        Output o = new Output();
        o.fileContent = strFileContent;
        outputResults.add(o);
		return outputResults;
    }
    
    public class RequestWrapper {
        public Parameters[] Parameters;
    }
    
    public class Parameters {
        public string Name;	//File
        public FileValue FileValue;
        public string Value;
    }
    public class FileValue {
        public string Name;	//ai-workshops.pdf
        public string Data;	
    }
    
    
    public class ResponseWrapper {
        public Integer ConversionCost;	//1
        public Files[] Files;
    }
    
    public class Files {
        public String FileName;	//agentforce-test-output-file.txt
        public String FileExt;	//txt
        public Integer FileSize;	//5205
        public String FileData;	
    }
}