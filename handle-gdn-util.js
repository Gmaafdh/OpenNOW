/* Copyright (c) 2023, NVIDIA CORPORATION.  All rights reserved.
 *
 * NVIDIA CORPORATION and its licensors retain all intellectual property
 * and proprietary rights in and to this software, related documentation
 * and any modifications thereto.  Any use, reproduction, disclosure or
 * distribution of this software and related documentation without an express
 * license agreement from NVIDIA CORPORATION is strictly prohibited.
 */

// Removing the splash logo for GDN Flow
const element = document.getElementById('splash-gfn-logo');
if (window['isGDNDomain']) {
    element.remove();
} else {
    element.style.display = 'block';
}
