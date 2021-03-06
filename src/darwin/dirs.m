/*****************************************************************************
 * darwin_dirs.c: Darwin directories configuration
 *****************************************************************************
 * Copyright (C) 2001-2016 VLC authors and VideoLAN
 * Copyright (C) 2007-2012 Rémi Denis-Courmont
 *
 * Authors: Rémi Denis-Courmont
 *          Felix Paul Kühne <fkuehne at videolan dot org>
 *          Pierre d'Herbemont <pdherbemont # videolan org>
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <vlc_common.h>
#include <vlc_charset.h>
#include "../libvlc.h"

#include <libgen.h>
#include <dlfcn.h>

#include <Foundation/Foundation.h>

static bool isBundle()
{
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *bundlePath = bundle.bundlePath;
    return [bundlePath hasSuffix:@".app"] || [bundlePath hasSuffix:@".framework"];
}

char *config_GetLibDir (void)
{
    if (isBundle()) {
        NSBundle *bundle = [NSBundle mainBundle];
        NSString *path = bundle.privateFrameworksPath;
        if (!path)
            return NULL;

        return strdup(path.UTF8String);
    }

    /* we are not part of any Mac-style package but were installed
     * the UNIX way. let's trick-around a bit */
    Dl_info info;
    if (dladdr(system_Init, &info)) {
        char *incompletepath = strdup(dirname( (char *)info.dli_fname ));
        char *path = NULL;
        asprintf(&path, "%s/"PACKAGE, incompletepath);
        free(incompletepath);
        return path;
    }

    /* should never happen */
    abort ();
}

static char *config_GetDataDir(void)
{
    const char *path = getenv ("VLC_DATA_PATH");
    if (path)
        return strdup (path);

    if (isBundle()) {
        NSBundle *bundle = [NSBundle mainBundle];
        NSString *path = bundle.resourcePath;
        if (!path)
            return NULL;

        path = [path stringByAppendingPathComponent:@"share"];
        return strdup(path.UTF8String);
    }

    // Fallback
    char *vlcpath = config_GetLibDir ();
    char *datadir;

    if (asprintf (&datadir, "%s/share", vlcpath) == -1)
        datadir = NULL;

    free (vlcpath);
    return datadir;
}

char *config_GetSysPath(vlc_sysdir_t type, const char *filename)
{
    char *dir = NULL;

    switch (type)
    {
        case VLC_PKG_DATA_DIR:
            dir = config_GetDataDir();
            break;
        case VLC_PKG_LIB_DIR:
        case VLC_PKG_LIBEXEC_DIR:
            dir = config_GetLibDir();
            break;
        case VLC_SYSDATA_DIR:
            break;
        case VLC_LOCALE_DIR:
            dir = config_GetSysPath(VLC_PKG_DATA_DIR, "locale");
            break;
        default:
            vlc_assert_unreachable();
    }

    if (filename == NULL || unlikely(dir == NULL))
        return dir;

    char *path;
    asprintf(&path, "%s/%s", dir, filename);
    free(dir);
    return path;
}

static char *config_GetHomeDir (void)
{
    const char *home = getenv ("HOME");

    if (home == NULL)
        home = "/tmp";

    return strdup (home);
}

static char *getAppDependentDir(vlc_userdir_t type)
{
    NSString *formatString;
    switch (type) {
        case VLC_CONFIG_DIR:
            formatString = @"%s/Library/Preferences/%@";
            break;
        case VLC_TEMPLATES_DIR:
        case VLC_USERDATA_DIR:
            formatString = @"%s/Library/Application Support/%@";
            break;
        case VLC_CACHE_DIR:
            formatString = @"%s/Library/Caches/%@";
            break;
        default:
            vlc_assert_unreachable();
            break;
    }

    // Default fallback
    NSString *identifier = @"org.videolan.vlc";
    NSBundle *mainBundle = [NSBundle mainBundle];
    if (mainBundle) {
        NSString *bundleId = mainBundle.bundleIdentifier;
        if (bundleId)
            identifier = bundleId;
    }

    char *homeDir = config_GetHomeDir();
    NSString *result = [NSString stringWithFormat:formatString, homeDir, identifier];
    free(homeDir);
    return strdup(result.UTF8String);
}

char *config_GetUserDir (vlc_userdir_t type)
{
    const char *psz_path;
    switch (type) {
        case VLC_CONFIG_DIR:
        case VLC_TEMPLATES_DIR:
        case VLC_USERDATA_DIR:
        case VLC_CACHE_DIR:
            return getAppDependentDir(type);

        case VLC_DESKTOP_DIR:
            psz_path = "%s/Desktop";
            break;
        case VLC_DOWNLOAD_DIR:
            psz_path = "%s/Downloads";
            break;
        case VLC_DOCUMENTS_DIR:
            psz_path = "%s/Documents";
            break;
        case VLC_MUSIC_DIR:
            psz_path = "%s/Music";
            break;
        case VLC_PICTURES_DIR:
            psz_path = "%s/Pictures";
            break;
        case VLC_VIDEOS_DIR:
            psz_path = "%s/Movies";
            break;
        case VLC_PUBLICSHARE_DIR:
            psz_path = "%s/Public";
            break;
        case VLC_HOME_DIR:
        default:
            psz_path = "%s";
    }
    char *psz_parent = config_GetHomeDir();
    char *psz_dir;
    if (asprintf( &psz_dir, psz_path, psz_parent ) == -1)
        psz_dir = NULL;
    free(psz_parent);
    return psz_dir;
}
