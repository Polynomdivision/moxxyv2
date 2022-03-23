import re

import yaml

def generateToJson(name, attributes):
    json = "\tMap<String, dynamic> toJson() => {\n"

    for attr in attributes:
        json += "\t\t\"" + attr + "\": " + attr + ",\n"

    json += "\t\t\"type\": \"" + name + "\"\n"    
    json += "\t};\n"
    return json

def generateFromJsonListBuilder(attrName, attrType, deserialise=False):
    if "List<" in attrType:
        listType = re.match("List\<(.*?)\>", attrType).groups()[0]
        suffix = " ?? []" if "?" in attrType else "!"
        data = "(json[\"" + attrName + "\"]" + suffix + ")"
        if deserialise:
            data += ".map((item) => {}.fromJson(item))".format(listType)
        return "\t\t" + attrName + ": List<" + listType + ">.from(" + data + "),\n";

    if deserialise:
        return "\t\t" + attrName + ": " + attrType + ".fromJson(json[\"" + attrName + "\"]" + ("" if attrType.endswith("?") else "!") + "),\n"

    return "\t\t" + attrName + ": json[\"" + attrName + "\"]" + ("" if attrType.endswith("?") else "!") + ",\n"

def generateFromJson(name, attributes):
    json = "\tstatic " + name + " fromJson(Map<String, dynamic> json) => " + name + "(\n"

    for attr in attributes:
        json += generateFromJsonListBuilder(
            attr,
            getType(attributes[attr]),
            getSerialise(attributes[attr])
        )
    
    json += "\t);\n"
    
    return json

def generateBuilder(builderName, builderBaseClass, classes):
    func = builderBaseClass + f"? get{builderName}FromJson(Map<String, dynamic> json) " + "{\n"
    func += "\tswitch(json[\"type\"]!) {\n"

    for c in classes:
        func += "\t\tcase \"" + c["name"] + "\": return " + c["name"] + ".fromJson(json);\n"
    
    func += "\t\tdefault: return null;\n"
    func += "\t}\n"
    func += "}\n"
    return func

def getType(val):
    if type(val) is dict:
        return val["type"]
    return val

def getSerialise(val):
    if type(val) is dict:
        return val["deserialise"]
    return False

def handleRequired(type_):
    return "required " if not type_.endswith("?") else ""

def main():
    with open("data_classes.yaml", "r") as f:
        data = yaml.load(f.read(), Loader=yaml.Loader)

    for f in data["files"]:
        # Generate imports
        content = "//// AUTO-GENERATED by tools/generate_data_classes.py ////\n"
        content += "/// DO NOT EDIT BY HAND\n"

        partof = f.get("partof", "")
        if partof:
            content += "part of \"" + partof + "\";\n\n"
        
        # Generate classes
        for c in f.get("classes", []):
            extends = ", ".join(c["extends"])
            implements = ", ".join(c["implements"])
            content += f"class {c['name']} extends {extends} implements {implements}" + " {\n"
            attributes = c.get("attributes", [])
            for attr in attributes:
                content += "\tfinal {} {};\n".format(getType(c["attributes"][attr]), attr)
            content += "\n"

            if attributes:
                content += "\t" + c["name"] + "({ " + ", ".join([
                    handleRequired(getType(c["attributes"][name])) + "this." + name for name in attributes
                ]) + " });\n\n"
            else:
                content += "\t" + c["name"] + "();\n\n";

            content += "\t// JSON stuff\n"
            content += generateToJson(c["name"], attributes)
            content += generateFromJson(c["name"], attributes)
            
            content += "}\n\n"

        if f["generate_builder"]:
            content += generateBuilder(
                f["builder_name"],
                f["builder_baseclass"],
                f.get("classes", [])
            )
            
        with open(f["path"], "w") as file_:
            file_.write(content[:-1])
            print("[i] Wrote " + f["path"])
        

if __name__ == "__main__":
    main()
