# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2009-2016 Stephan Raue (stephan@openelec.tv)
# Copyright (C) 2018-present Team LibreELEC (https://libreelec.tv)

PKG_NAME="mesa"
PKG_VERSION="19.2.0-rc1"
PKG_SHA256="e4d93e91a8ced0b4d068a5b2f9eee978a221ad20bb1284944d2ce89b1cdb9cad"
PKG_LICENSE="OSS"
PKG_SITE="http://www.mesa3d.org/"
PKG_URL="https://github.com/mesa3d/mesa/archive/mesa-${PKG_VERSION}.tar.gz"
PKG_DEPENDS_TARGET="toolchain expat libdrm Mako:host"
PKG_LONGDESC="The Mesa 3D Graphics Library, is an open source software implementation of OpenGL, Vulkan, and other graphics API specifications."
PKG_TOOLCHAIN="meson"

get_graphicdrivers

PKG_MESON_OPTS_TARGET="-Ddri-drivers=${DRI_DRIVERS// /,} \
                       -Dgallium-drivers=${GALLIUM_DRIVERS// /,} \
                       -Dgallium-extra-hud=false \
                       -Dgallium-xvmc=false \
                       -Dgallium-omx=disabled \
                       -Dgallium-nine=false \
                       -Dgallium-opencl=disabled \
                       -Dvulkan-drivers= \
                       -Dshader-cache=true \
                       -Dshared-glapi=true \
                       -Dopengl=true \
                       -Dgbm=true \
                       -Degl=true \
                       -Dglvnd=false \
                       -Dvalgrind=false \
                       -Dlibunwind=false \
                       -Dlmsensors=false \
                       -Dbuild-tests=false \
                       -Dselinux=false \
                       -Dosmesa=none"

if [ "${DISPLAYSERVER}" = "x11" ]; then
  PKG_DEPENDS_TARGET+=" xorgproto libXext libXdamage libXfixes libXxf86vm libxcb libX11 libxshmfence libXrandr"
  export X11_INCLUDES=
  PKG_MESON_OPTS_TARGET+=" -Dplatforms=x11,drm -Ddri3=true -Dglx=dri"
elif [ "${DISPLAYSERVER}" = "weston" ]; then
  PKG_DEPENDS_TARGET+=" wayland wayland-protocols"
  PKG_MESON_OPTS_TARGET+=" -Dplatforms=wayland,drm -Ddri3=false -Dglx=disabled"
else
  PKG_MESON_OPTS_TARGET+=" -Dplatforms=drm -Ddri3=false -Dglx=disabled"
fi

if [ "${LLVM_SUPPORT}" = "yes" ]; then
  PKG_DEPENDS_TARGET+=" elfutils llvm"
  export LLVM_CONFIG="${SYSROOT_PREFIX}/usr/bin/llvm-config-host"
  PKG_MESON_OPTS_TARGET+=" -Dllvm=true"
else
  PKG_MESON_OPTS_TARGET+=" -Dllvm=false"
fi

if [ "${VDPAU_SUPPORT}" = "yes" -a "${DISPLAYSERVER}" = "x11" ]; then
  PKG_DEPENDS_TARGET+=" libvdpau"
  PKG_MESON_OPTS_TARGET+=" -Dgallium-vdpau=true"
else
  PKG_MESON_OPTS_TARGET+=" -Dgallium-vdpau=false"
fi

if [ "${VAAPI_SUPPORT}" = "yes" ] && listcontains "${GRAPHIC_DRIVERS}" "(r600|radeonsi)"; then
  PKG_DEPENDS_TARGET+=" libva"
  PKG_MESON_OPTS_TARGET+=" -Dgallium-va=true"
else
  PKG_MESON_OPTS_TARGET+=" -Dgallium-va=false"
fi

if listcontains "${GRAPHIC_DRIVERS}" "vmware"; then
  PKG_MESON_OPTS_TARGET+=" -Dgallium-xa=true"
else
  PKG_MESON_OPTS_TARGET+=" -Dgallium-xa=false"
fi

if [ "${OPENGLES_SUPPORT}" = "yes" ]; then
  PKG_MESON_OPTS_TARGET+=" -Dgles1=false -Dgles2=true"
else
  PKG_MESON_OPTS_TARGET+=" -Dgles1=false -Dgles2=false"
fi

# Temporary workaround:
# Listed libraries are static, while mesa expects shared ones. This breaks the
# dependency tracking. The following has some ideas on how to address that.
# https://github.com/LibreELEC/LibreELEC.tv/pull/2163
pre_configure_target() {
  if [ "${DISPLAYSERVER}" = "x11" ]; then
    export LIBS="-lxcb-dri3 -lxcb-dri2 -lxcb-xfixes -lxcb-present -lxcb-sync -lxshmfence -lz"
  fi

  # Temporary hack (until panfrost evolves) to use 64-bit pointers in structs passed to GPU
  # even if userspace is 32-bit. This is required for Mali-T8xx to work with mesa built for
  # arm userspace. The hack does not affect building for aarch64.
  if [[ "${MALI_FAMILY}" = *t8* ]]; then
    (
      cd "${PKG_BUILD}/src/gallium/drivers/panfrost"
      sed -i 's/uintptr_t/uint64_t/g' include/panfrost-job.h \
                                      include/panfrost-misc.h \
                                      pan_context.c \
                                      pandecode/decode.c

      find -type f -exec sed -i 's/ndef __LP64__/ 0/g; s/def __LP64__/ 1/g' {} +;
    )
  fi
}

post_makeinstall_target() {
  # Similar hack is needed on EGL, GLES* front. Might as well drop it and test the GLVND?
  if [ "${DISPLAYSERVER}" = "x11" ]; then
    # rename and relink for cooperate with nvidia drivers
    safe_remove ${INSTALL}/usr/lib/libGL.so
    safe_remove ${INSTALL}/usr/lib/libGL.so.1
    ln -sf libGL.so.1 ${INSTALL}/usr/lib/libGL.so
    ln -sf /var/lib/libGL.so ${INSTALL}/usr/lib/libGL.so.1
    mv ${INSTALL}/usr/lib/libGL.so.1.2.0 ${INSTALL}/usr/lib/libGL_mesa.so.1
  fi
}
