package dmcore

import "core:fmt"
import "core:strings"
import "core:os"

when ODIN_OS != .JS {
    ASSETS_ROOT :: #config(ASSET_ROOT, "../assets/")
}
else {
    ASSETS_ROOT :: #config(ASSET_ROOT, "./assets/")
}

TextureAssetDescriptor :: struct {
    filter: TextureFilter
}

ShaderAssetDescriptor :: struct {
}

FontAssetDescriptor :: struct {
    fontType: FontType,
    fontSize: int,
}

SoundAssetDescriptor :: struct {
}

RawFileAssetDescriptor :: struct {
}

AssetDescriptor :: union {
    TextureAssetDescriptor,
    ShaderAssetDescriptor,
    FontAssetDescriptor,
    SoundAssetDescriptor,
    RawFileAssetDescriptor,
}

AssetData :: struct {
    fileName: string,

    fileData: []u8,

    lastWriteTime: os.File_Time,

    handle: Handle,

    descriptor: AssetDescriptor
}

Assets :: struct {
    assetsMap: map[string]AssetData,
    toLoad: [dynamic]string
}

RegisterAsset :: proc(fileName: string, desc: AssetDescriptor) {
    RegisterAssetCtx(assets, fileName, desc)
}

RegisterAssetCtx :: proc(assets: ^Assets, fileName: string, desc: AssetDescriptor) {
    if fileName in assets.assetsMap {
        fmt.eprintln("Duplicated asset file name:", fileName, ". Skipping...")
        return
    }

    clonedName := strings.clone(fileName)
    assets.assetsMap[clonedName] = AssetData {
        fileName = clonedName,
        descriptor = desc,
    }

    append(&assets.toLoad, clonedName)
}

GetAssetData :: proc(fileName: string) -> ^AssetData {
    return GetAssetDataCtx(assets, fileName)
}

GetAssetDataCtx :: proc(assets: ^Assets, fileName: string) -> ^AssetData {
    return &assets.assetsMap[fileName]
}


GetAsset :: proc(fileName: string) -> Handle {
    return GetAssetCtx(assets, fileName)
}

GetAssetCtx :: proc(assets: ^Assets, fileName: string) -> Handle {
    return assets.assetsMap[fileName].handle
}

GetTextureAsset :: proc(fileName: string) -> TexHandle {
    return cast(TexHandle) GetAssetCtx(assets, fileName)
}

GetTextureAssetCtx :: proc(assets: ^Assets, fileName: string) -> TexHandle {
    return cast(TexHandle) GetAssetCtx(assets, fileName)
}

// @TODO: ReloadAsset

ReleaseAssetData :: proc(fileName: string) {
    ReleaseAssetDataCtx(assets, fileName)
}

ReleaseAssetDataCtx :: proc(assets: ^Assets, fileName: string) {
    assetData, ok := &assets.assetsMap[fileName]
    if ok && assetData.fileData != nil {
        delete(assetData.fileData)
        assetData.fileData = nil
    }
}