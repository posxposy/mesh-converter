package;

import assimp.AiFace;
import assimp.AiMaterial;
import assimp.AiMesh;
import assimp.AiNode;
import assimp.AiPostProcess;
import assimp.AiScene;
import assimp.AiString;
import assimp.AiTextureType;
import cpp.Lib;
import assimp.AssimpImporter;
import cpp.Pointer;
import cpp.Star;
import cpp.zip.Compress;
import haxe.Json;
import haxe.io.Bytes;
import org.msgpack.MsgPack;
import sys.io.File;

/**
 * ...
 * @author Dmitry Hryppa	http://themozokteam.com/
 */

@:buildXml('
    <files id="haxe">
        <compilerflag value="-I${haxelib:assimp-haxe}/../cpp/assimp/include"/>
    </files>
    <files id="__main__">
        <compilerflag value="-I${haxelib:assimp-haxe}/../cpp/assimp/include"/>
    </files>
    
    <target id="haxe">
        <lib name = "../lib/assimp.lib" if="windows" />
    </target>
')

class Main
{
    private static var importer:AssimpImporter;
    private static var scene:Pointer<AiScene>;
    private static var outputModel:ModelStruct;
    private static var calcTangents:Bool = false;
    public static function main():Void
    {
        var args:Array<String> = Sys.args();
        var inputFile:String = "";
        if (args[0] != null) {
            inputFile = args[0];
        } else {
            Lib.println("Required input file path.");
            return;
        }
        
        var outputFile:String = args[1] != null ? args[1] : "out.3Dmodel";
        var bin:Bool = false;
        var zip:Bool = false;
        var flags:Int = AiPostProcess.flipUVs;
        
        for (i in 1...args.length) { 
            switch(args[i]) {
                case "triangulate": {
                    flags |= AiPostProcess.triangulate;
                }
                case "calctangents": {
                    flags |= AiPostProcess.calcTangentSpace;
                    calcTangents = true;
                }
                case "bin": {
                    bin = true;
                }
                case "zip": {
                    zip = true;
                }
            }
        }
        
        importer = new AssimpImporter();
        scene = importer.readFileFromMemory(File.getBytes(inputFile).getData(), flags);//importer.readFile(inputFile, flags);
        if (scene == null || scene.ptr.flags == AiScene.AI_SCENE_FLAGS_INCOMPLETE || scene.ptr.rootNode == null) {
            Lib.println("Something went wrong.");
            return;
        }
        
        outputModel = {
            meshes: new Array<MeshStruct>()
        };
        
        processNode(scene.ptr.rootNode);
        
        if (bin) {
            var bytes:Bytes = MsgPack.encode(outputModel);
            if (zip) bytes = Compress.run(bytes, 3);
            File.saveBytes(outputFile, bytes);
        } else {
            File.saveContent(outputFile, Json.stringify(outputModel));
        }
        
        Lib.println("Done. Saved to: " + outputFile);
    }
    
    private static function processNode(node:Pointer<AiNode>):Void
    {
        for (i in 0...node.ptr.numMeshes) {
            var meshIndex:Int = node.ptr.meshes[i];
            processMesh(node, scene.ptr.meshes[meshIndex], i);
        }
        
        for (i in 0...node.ptr.numChildren) {
            processNode(node.ptr.children[i]);
        }
    }
    
    private static function processMesh(node:Pointer<AiNode>, aiMesh:Pointer<AiMesh>, index:Int):Void
    {
        var indices:Array<Int> = new Array<Int>();
        var vertices:Array<Float> = new Array<Float>();
        var normals:Array<Float> = new Array<Float>();
        var tangents:Array<Float> = new Array<Float>();
        var bitangents:Array<Float> = new Array<Float>();
        var uv:Array<Float> = new Array<Float>();
        var colors:Array<Float> = new Array<Float>();
        
        for (i in 0...aiMesh.ptr.numVertices) {
            vertices.push(aiMesh.ptr.vertices[i].x);
            vertices.push(aiMesh.ptr.vertices[i].y);
            vertices.push(aiMesh.ptr.vertices[i].z);
            
            normals.push(aiMesh.ptr.normals[i].x);
            normals.push(aiMesh.ptr.normals[i].y);
            normals.push(aiMesh.ptr.normals[i].z);
            
            if (aiMesh.ptr.hasVertexColors(index)) {
                colors.push(aiMesh.ptr.colors[index][i].r);
                colors.push(aiMesh.ptr.colors[index][i].g);
                colors.push(aiMesh.ptr.colors[index][i].b);
                colors.push(aiMesh.ptr.colors[index][i].a);
            }
            
            if (aiMesh.ptr.textureCoords[0] != null) {
                uv.push(aiMesh.ptr.textureCoords[0][i].x);
                uv.push(aiMesh.ptr.textureCoords[0][i].y);
                
                if (calcTangents) {
                    tangents.push(aiMesh.ptr.tangents[i].x);
                    tangents.push(aiMesh.ptr.tangents[i].y);
                    tangents.push(aiMesh.ptr.tangents[i].z);
                    
                    bitangents.push(aiMesh.ptr.bitangents[i].x);
                    bitangents.push(aiMesh.ptr.bitangents[i].y);
                    bitangents.push(aiMesh.ptr.bitangents[i].z);
                }
            }
        }
        
        for (i in 0...aiMesh.ptr.numFaces) {
            var aiFace:AiFace = aiMesh.ptr.faces[i];
            for (j in 0...aiFace.numIndices) {
                var index:Int = aiFace.indices[j];
                indices.push(index);
            }
        }
        
        var mesh:MeshStruct = {
            indices: indices,
            vertices: vertices,
            normals: normals,
            colors:colors,
            transformMatrix : {
                a1: node.ptr.transformation.a1,
                a2: node.ptr.transformation.a2,
                a3: node.ptr.transformation.a3,
                a4: node.ptr.transformation.a4,
                b1: node.ptr.transformation.b1,
                b2: node.ptr.transformation.b2,
                b3: node.ptr.transformation.b3,
                b4: node.ptr.transformation.b4,
                c1: node.ptr.transformation.c1,
                c2: node.ptr.transformation.c2,
                c3: node.ptr.transformation.c3,
                c4: node.ptr.transformation.c4,
                d1: node.ptr.transformation.d1,
                d2: node.ptr.transformation.d2,
                d3: node.ptr.transformation.d3,
                d4: node.ptr.transformation.d4
            }
        };
        
        if (uv.length > 0) {
            mesh.uv = uv;
            if (tangents.length > 0) {
                mesh.tangents = tangents;
            }
            if (bitangents.length > 0) {
                mesh.bitangents = bitangents;
            }
        }
        
        if (scene.ptr.hasMaterials()) {
            var diffuseTexture:String = "";
            var normalsTexture:String = "";
            var diffuseColor:Vec4Struct = {x: 0, y: 0, z: 0, w: 0};
            if (aiMesh.ptr.materialIndex >= 0) {
                var aiMaterial:Pointer<AiMaterial> = scene.ptr.materials[aiMesh.ptr.materialIndex];
                var path:Pointer<AiString> = AiString.create();
                
                var diffuseCount:Int = aiMaterial.ptr.getTextureCount(AiTextureType.aiTextureType_DIFFUSE);
                if (diffuseCount > 0) {
                    aiMaterial.ptr.getTexture(AiTextureType.aiTextureType_DIFFUSE, 0, path.ptr);
                    diffuseTexture =  path.ptr.c_str().toString();
                }
                
                var normalsCount:Int = aiMaterial.ptr.getTextureCount(AiTextureType.aiTextureType_NORMALS);
                if (normalsCount > 0) {
                    aiMaterial.ptr.getTexture(AiTextureType.aiTextureType_NORMALS, 0, path.ptr);
                    normalsTexture = path.ptr.c_str().toString();
                }
                
                path.destroy();
                path = null;
            }
            
            mesh.material = {
                diffuseTexture: diffuseTexture,
                normalsTexture: normalsTexture,
                diffuseColor: diffuseColor
            };
        }
        
        outputModel.meshes.push(mesh);
    }
    
    /*private static function getTextures(aiMaterial:Star<AiMaterial>, count:Int, type:String):Array<String>
    {
        var textures:Array<String> = new Array<String>();
        
        for (i in 0...count) {
            var path:Pointer<AiString> = AiString.create();
            switch(type) {
                case "diffuse": {
                    aiMaterial.getTexture(AiTextureType.aiTextureType_DIFFUSE, i, path.ptr);
                }
                case "normals": {
                    aiMaterial.getTexture(AiTextureType.aiTextureType_NORMALS, i, path.ptr);
                }
            }
            textures.push(path.ptr.c_str().toString());
            path.destroy();
            path = null;
        }
        
        return textures;
    }*/
    
}

typedef ModelStruct =
{
    var meshes:Array<MeshStruct>;
}

typedef MeshStruct =
{
    var indices:Array<Int>;
    var vertices:Array<Float>;
    var normals:Array<Float>;
    var transformMatrix:Mat4Struct;
    @:optional var uv:Array<Float>;
    @:optional var material:MaterialStruct;
    @:optional var tangents:Array<Float>;
    @:optional var bitangents:Array<Float>;
    @:optional var colors:Array<Float>;
}

typedef Mat4Struct = 
{
    var a1:Float;
    var a2:Float;
    var a3:Float;
    var a4:Float;
    
    var b1:Float;
    var b2:Float;
    var b3:Float;
    var b4:Float;
    
    var c1:Float;
    var c2:Float;
    var c3:Float;
    var c4:Float;
    
    var d1:Float;
    var d2:Float;
    var d3:Float;
    var d4:Float;
}

typedef MaterialStruct =
{
    var diffuseTexture:String;
    var normalsTexture:String;
    var diffuseColor:Vec3Struct;
}

typedef Vec3Struct =
{
    var x:Float;
    var y:Float;
    var z:Float;
}

typedef Vec4Struct =
{
    var x:Float;
    var y:Float;
    var z:Float;
    var w:Float;
}