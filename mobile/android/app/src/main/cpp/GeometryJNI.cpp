#include <jni.h>
#include "Geometry.hpp"
extern "C" JNIEXPORT jdoubleArray JNICALL
Java_com_ameriframe_mosaic_NativeGeometry_frame(JNIEnv* env, jobject, jstring id, jint count, jdouble w, jdouble h, jdouble gap) {
    const char* chars=env->GetStringUTFChars(id,nullptr);
    if(!chars)return nullptr;
    std::string layout(chars);env->ReleaseStringUTFChars(id,chars);
    try {
        auto data=mosaic::packedFrame(layout,count,w,h,gap);
        auto result=env->NewDoubleArray(static_cast<jsize>(data.size()));
        if(result)env->SetDoubleArrayRegion(result,0,static_cast<jsize>(data.size()),data.data());return result;
    } catch(const std::exception& e) {
        env->ThrowNew(env->FindClass("java/lang/IllegalArgumentException"),e.what());return nullptr;
    }
}
extern "C" JNIEXPORT jobjectArray JNICALL
Java_com_ameriframe_mosaic_NativeGeometry_catalog(JNIEnv* env, jobject) {
    auto& layouts=mosaic::layouts();auto stringClass=env->FindClass("java/lang/String");
    auto result=env->NewObjectArray(static_cast<jsize>(layouts.size()*4),stringClass,nullptr);
    if(!result)return nullptr;
    int i=0;for(auto item:layouts)for(auto field:{item.id,item.category,item.vi,item.en}) {
        auto value=env->NewStringUTF(field);env->SetObjectArrayElement(result,i++,value);env->DeleteLocalRef(value);
    }
    return result;
}
