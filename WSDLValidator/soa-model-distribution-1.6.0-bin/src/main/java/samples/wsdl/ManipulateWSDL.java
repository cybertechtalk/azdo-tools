/* Copyright 2012 predic8 GmbH, www.predic8.com

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License. */

package samples.wsdl;

import com.predic8.wsdl.*;
import com.predic8.schema.*;
import static com.predic8.schema.Schema.*;

public class ManipulateWSDL {

  public static void main(String[] args) {
    WSDLParser parser = new WSDLParser();

    Definitions wsdl = parser.parse("http://www.thomas-bayer.com/axis2/services/BLZService?wsdl");
    
    Schema schema = wsdl.getSchema("http://thomas-bayer.com/blz/");
    schema.newElement("listprojects").newComplexType().newSequence();
    Sequence seq = schema.newElement("listprojectsResponse").newComplexType().newSequence();
    seq.newElement("project", STRING);
    seq.newElement("name", STRING);
    
    PortType pt = wsdl.getPortType("BLZServicePortType");
    Operation op = pt.newOperation("listprojects");
    op.newInput("listprojects").newMessage("listprojects").newPart("parameters", "tns:listprojects");
    op.newOutput("listprojectsResponse").newMessage("listprojectsResponse").newPart("parameters", "tns:listprojectsResponse");
    
    Binding bnd = wsdl.getBinding("BLZServiceSOAP11Binding");
    BindingOperation bo = bnd.newBindingOperation("listprojects");
    bo.newSOAP11Operation();
    bo.newInput().newSOAP11Body();
    bo.newOutput().newSOAP11Body();
    
    System.out.println(wsdl.getAsString());
  }
}